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

    with subtest("scheduled jobs"):
        pi.wait_for_unit("check-facade.timer")
        pi.wait_for_unit("pccomponentes.timer")
        pi.succeed("systemctl cat ddclient.service")
  '';
}
