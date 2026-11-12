# Boots everything in hosts/pi/configuration.nix in an x86_64 VM and checks that each site
# and service answers. Run with: nix build .#checks.x86_64-linux.pi -L
# Let's Encrypt isn't reachable from the VM, so nginx serves its self-signed placeholder certs.
{ pkgs, inputs }:
pkgs.testers.runNixOSTest {
  name = "pi";
  node.specialArgs = { inherit inputs; };

  nodes.pi = { lib, pkgs, ... }: {
    imports = [ ../hosts/pi/configuration.nix ];

    virtualisation = {
      memorySize = 4096;
      cores = 4;
      diskSize = 8192;
    };

    # Dummy secrets (all "test"), encrypted for the throwaway key next to this file
    sops.defaultSopsFile = lib.mkForce ./secrets.yaml;
    sops.age.sshKeyPaths = lib.mkForce [ ];
    sops.age.keyFile = "/run/test-age-key.txt";
    # sops-nix won't read a key from the Nix store, so put it in place before it decrypts
    system.activationScripts.testAgeKey.text = "install -m 600 ${./age-key.txt} /run/test-age-key.txt";
    system.activationScripts.setupSecrets.deps = [ "testAgeKey" ];
    system.activationScripts.setupSecretsForUsers.deps = [ "testAgeKey" ];

    security.acme.defaults.server = "https://acme.invalid/directory";

    environment.systemPackages = [ pkgs.mosquitto ];
  };

  testScript = ''
    def https(host, path="/"):
        return pi.succeed(
            f"curl -sk -o /dev/null -w '%{{http_code}}' --resolve {host}:443:127.0.0.1 'https://{host}{path}'"
        )

    def expect(host, path, wanted):
        status = https(host, path)
        assert status == wanted, f"{host}{path}: got {status}, wanted {wanted}"

    pi.wait_for_unit("multi-user.target")
    pi.wait_for_unit("nginx.service")

    with subtest("static sites"):
        for host in [
            "bearkillerpt.xyz",
            "www.bearkillerpt.xyz",
            "plughere.app",
            "www.plughere.app",
            "heaboo.bearkillerpt.xyz",
            "iv.bearkillerpt.xyz",
            "ed.bearkillerpt.xyz",
            "bdl.bearkillerpt.xyz",
        ]:
            expect(host, "/", "200")

    with subtest("unknown names are dropped"):
        pi.fail("curl -sk --resolve nope.bearkillerpt.xyz:443:127.0.0.1 https://nope.bearkillerpt.xyz/")

    with subtest("mqtt needs the password"):
        pi.wait_for_unit("mosquitto.service")
        pi.succeed("mosquitto_pub -h 127.0.0.1 -p 1883 -u park2ChargeDemo -P test -t ping -m hi")
        pi.fail("mosquitto_pub -h 127.0.0.1 -p 1883 -t ping -m hi")

    with subtest("plughere api, emulators and websocket broker"):
        # On the real Pi this role and database come from the old pg_dumpall
        pi.wait_for_unit("postgresql.service")
        pi.succeed("runuser -u postgres -- psql -c 'CREATE ROLE \"plugHereAPI\" LOGIN PASSWORD $$test$$'")
        pi.succeed("runuser -u postgres -- psql -c 'CREATE DATABASE \"plugHere\" OWNER \"plugHereAPI\"'")
        pi.succeed("systemctl restart plughere-api")
        pi.wait_for_open_port(3014)
        pi.wait_until_succeeds("journalctl -u plughere-api | grep -q 'Successfully connected to the MQTT broker'", timeout=120)
        # The emulators publish heartbeats over 1883, the API receives them over websockets
        pi.wait_until_succeeds("journalctl -u plughere-api | grep -q Heartbeat", timeout=120)
        for host in ["api.plughere.app", "plughereapi.bearkillerpt.xyz"]:
            status = https(host)
            assert status not in ("502", "504"), f"{host}: {status}"
        # The upgraded connection stays open, so curl only stops at its timeout
        status = pi.succeed(
            "curl -sk -m 5 -o /dev/null -w '%{http_code}' --http1.1 --resolve mosquitto.plughere.app:443:127.0.0.1"
            " -H 'Connection: Upgrade' -H 'Upgrade: websocket' -H 'Sec-WebSocket-Version: 13'"
            " -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' -H 'Sec-WebSocket-Protocol: mqtt'"
            " https://mosquitto.plughere.app/ || true"
        )
        assert status == "101", f"mosquitto websocket handshake: {status}"

    with subtest("edapi"):
        pi.wait_for_open_port(3003, timeout=900)
        expect(
            "edapi.bearkillerpt.xyz",
            "/?gender=1&age=67&hypertension=0&heart_disease=1&ever_married=1&work_type=2"
            "&Residence_type=1&avg_glucose_level=228&bmi=36&smoking_status=1",
            "200",
        )

    with subtest("gotify"):
        pi.wait_for_open_port(8082)
        expect("gotify.bearkillerpt.xyz", "/health", "200")

    with subtest("nextcloud"):
        # nextcloud-setup is a oneshot: it goes inactive once it's done
        pi.wait_until_succeeds("nextcloud-occ status | grep -q 'installed: true'", timeout=300)
        expect("nextcloud.bearkillerpt.xyz", "/status.php", "200")

    with subtest("price tracker"):
        pi.wait_for_unit("price-tracker.service")
        pi.wait_for_open_port(4380)
        expect("price-tracker.bearkillerpt.xyz", "/api/health", "200")
        expect("price-tracker.bearkillerpt.xyz", "/", "200")
        pi.succeed("echo 'a test password' | runuser -u price-tracker -- price-tracker reset-password --password-stdin")

    with subtest("home assistant"):
        import json

        pi.wait_for_unit("home-assistant.service")
        pi.wait_for_open_port(8123, timeout=600)
        pi.succeed("grep -qxF '[]' /var/lib/hass/automations.yaml")
        # Onboard a throwaway owner for a token, then ask HA to check configuration.yaml
        hass = "http://127.0.0.1:8123"
        user = json.dumps({"client_id": f"{hass}/", "name": "Test", "username": "test",
                           "password": "a test password", "language": "en"})
        code = json.loads(pi.succeed(f"curl -sf {hass}/api/onboarding/users -H 'Content-Type: application/json' -d '{user}'"))["auth_code"]
        token = json.loads(pi.succeed(
            f"curl -sf {hass}/auth/token -d grant_type=authorization_code -d code={code} -d client_id={hass}/"
        ))["access_token"]
        auth = f"-H 'Authorization: Bearer {token}'"
        pi.wait_until_succeeds(f"curl -sf {auth} {hass}/api/config | grep -q '\"state\": *\"RUNNING\"'", timeout=300)
        check = json.loads(pi.succeed(f"curl -sf -X POST {auth} {hass}/api/config/core/check_config"))
        assert check["result"] == "valid", check
        # Through nginx: HA refuses forwarded requests from proxies it doesn't trust (400)
        expect("ha.bearkillerpt.xyz", "/manifest.json", "200")
        status = pi.succeed(
            f"curl -sk -o /dev/null -w '%{{http_code}}' {auth} --resolve ha.bearkillerpt.xyz:443:127.0.0.1"
            " https://ha.bearkillerpt.xyz/api/config"
        )
        assert status == "200", f"ha.bearkillerpt.xyz/api/config: {status}"

    with subtest("home assistant: openhab integration"):
        # A stand-in openHAB: /rest/items is a static file
        items = [
            # The five facade probes, labelled as on the real openHAB (facade-alerts.nix uses their names)
            *[{"name": name, "label": label, "type": "Number", "state": value,
               "stateDescription": {"pattern": "%.1f °C"}}
              for name, label, value in [
                  ("T_S1", "T. ambiente exterior", "14.88"),
                  ("T_S2", "T. Fachada", "20.5"),
                  ("T_S3", "T. Ambiente interior", "17.0"),
                  ("T_S4", "T. Acumulador AQS", "43.6"),
                  ("T_S5", "T. Inércia", "16.3"),
              ]],
            {"name": "Escolha_AQS", "label": "Set Point AQS", "type": "Number:Temperature", "state": "50 °C",
             "stateDescription": {"pattern": "%.0f %unit%"}},
            {"name": "R3", "label": "R3-Bomba circuladora", "type": "Switch", "state": "ON"},
            {"name": "Resposta_S1", "label": "Resposta S1", "type": "Number", "state": "NULL"},
            {"name": "Camera", "label": "Image", "type": "Image", "state": "NULL"},
        ]

        def serve(items):
            pi.succeed(f"printf '%s' '{json.dumps(items)}' > /srv/openhab/rest/items")

        pi.succeed("mkdir -p /srv/openhab/rest")
        serve(items)
        pi.succeed(
            "systemd-run --unit fake-openhab -p WorkingDirectory=/srv/openhab"
            " ${pkgs.python3}/bin/python3 -m http.server 8099 --bind 127.0.0.1"
        )
        pi.wait_for_open_port(8099)

        # What the UI does when the integration is added
        def post(path, body):
            return json.loads(pi.succeed(
                f"curl -sf -X POST {auth} -H 'Content-Type: application/json' -d '{json.dumps(body)}' {hass}/api/{path}"
            ))

        flow = post("config/config_entries/flow", {"handler": "openhab"})
        result = post(f"config/config_entries/flow/{flow['flow_id']}", {"url": "http://127.0.0.1:8099/"})
        assert result["type"] == "create_entry", result

        def state(entity_id):
            return json.loads(pi.succeed(f"curl -sf {auth} {hass}/api/states/{entity_id}"))

        exterior = state("sensor.openhab_t_ambiente_exterior")
        assert float(exterior["state"]) == 14.88, exterior
        assert exterior["attributes"]["unit_of_measurement"] == "°C", exterior
        setpoint = state("sensor.openhab_set_point_aqs")
        assert float(setpoint["state"]) == 50 and setpoint["attributes"]["unit_of_measurement"] == "°C", setpoint
        assert state("binary_sensor.openhab_r3_bomba_circuladora")["state"] == "on"
        assert state("sensor.openhab_resposta_s1")["state"] == "unknown"
        # Read-only: nothing that could send openHAB a command
        states = json.loads(pi.succeed(f"curl -sf {auth} {hass}/api/states"))
        domains = {s["entity_id"].split(".")[0] for s in states if ".openhab_" in s["entity_id"]}
        assert domains == {"sensor", "binary_sensor"}, domains

        # A new openHAB item shows up on the next poll, with no config change
        items.append({"name": "T_S6", "label": "New probe", "type": "Number", "state": "1.5",
                      "stateDescription": {"pattern": "%.1f °C"}})
        serve(items)
        pi.wait_until_succeeds(f"curl -sf {auth} {hass}/api/states/sensor.openhab_new_probe", timeout=120)

    with subtest("home assistant: facade alerts"):
        alerts = ["openhab_unreachable", "probe_without_a_reading", "temperature_out_of_range",
                  "probe_stuck", "colder_than_outside"]
        for alert in alerts:
            assert state(f"automation.facade_{alert}")["state"] == "on", alert
        # Nothing is wrong yet
        for alert in alerts:
            assert state(f"automation.facade_{alert}")["attributes"]["last_triggered"] is None, alert
        # A probe beyond 100 °C alerts on the next poll (the phone isn't there; the HA notification is)
        serve([dict(i, state="150") if i["name"] == "T_S3" else i for i in items])
        pi.wait_until_succeeds(
            f"curl -sf {auth} {hass}/api/states/automation.facade_temperature_out_of_range"
            " | grep -q '\"last_triggered\": *\"'",
            timeout=120,
        )
        serve(items)

    with subtest("home assistant: solar sensors"):
        # No inverter in the VM: they exist, waiting for the meter
        for entity in ["sensor.home_power", "sensor.grid_power"]:
            assert state(entity)["state"] == "unavailable", entity

    with subtest("home assistant: matter"):
        # Added with the default address, as in the UI: only succeeds if HA can talk to the server
        pi.wait_for_unit("matter-server.service")
        pi.wait_for_open_port(5580, timeout=300)
        flow = post("config/config_entries/flow", {"handler": "matter"})
        assert flow["step_id"] == "manual", flow
        result = post(f"config/config_entries/flow/{flow['flow_id']}", {"url": "ws://localhost:5580/ws"})
        assert result["type"] == "create_entry", result
        pi.succeed("test $(sysctl -n net.netfilter.nf_conntrack_udp_timeout_stream) = 3600")

    with subtest("home assistant: huawei solar loads"):
        # Its first setup step only shows if the integration and its libraries import
        flow = post("config/config_entries/flow", {"handler": "huawei_solar"})
        assert flow["type"] in ("form", "menu"), flow
        pi.succeed(f"curl -sf -X DELETE {auth} {hass}/api/config/config_entries/flow/{flow['flow_id']}")

    with subtest("scheduled jobs"):
        pi.wait_for_unit("pccomponentes.timer")
        pi.succeed("systemctl cat ddclient.service")

    with subtest("pi has a console password"):
        pi.succeed("grep -q '^pi:\\$y\\$' /etc/shadow")
  '';
}
