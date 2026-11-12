# Alerts on the heating's facade probes, pushed to Gil's phone (the Home Assistant app) and kept
# in HA's notifications. They replace check-facade, which polled openHAB every 5 minutes and
# re-sent its Gotify alert on every run while a problem lasted. These fire once when a problem
# starts. Same rules:
#   - openHAB unreachable (and, new, back online)
#   - a probe with no reading
#   - a probe beyond ±100 °C
#   - the facade probe stuck on one value for 30 minutes
#   - the facade colder than outside
# They show in Settings → Automations, where they can be run by hand or switched off.
{ ... }:
let
  # The phone's name in the Home Assistant app (Settings → Companion app)
  phone = "notify.mobile_app_in2023";

  exterior = "sensor.openhab_t_ambiente_exterior";
  facade = "sensor.openhab_t_fachada";
  probes = [
    exterior
    facade
    "sensor.openhab_t_ambiente_interior"
    "sensor.openhab_t_acumulador_aqs"
    "sensor.openhab_t_inercia"
  ];

  # HA's own notification first: it's there even if the phone action fails (a renamed phone
  # makes the action unknown, which stops the rest of the automation). A notification with the
  # same tag replaces the previous one.
  notify = tag: title: message: [
    {
      action = "persistent_notification.create";
      data = {
        inherit title message;
        notification_id = tag;
      };
    }
    {
      action = phone;
      data = {
        inherit title message;
        data = {
          inherit tag;
          # Its own Android notification channel, so its sound and importance can be set apart
          channel = "Facade alerts";
        };
      };
    }
  ];

  minutes = m: { minutes = m; };
in
{
  services.home-assistant.config."automation nix" = [
    {
      id = "facade_openhab_unreachable";
      alias = "Facade: openHAB unreachable";
      description = "openHAB stops answering for 5 minutes, and when it's back.";
      mode = "queued";
      triggers = [
        {
          trigger = "state";
          entity_id = facade;
          to = "unavailable";
          for = minutes 5;
          id = "down";
        }
        {
          trigger = "state";
          entity_id = facade;
          from = "unavailable";
          id = "up";
        }
      ];
      # "Back online" only after an outage that was reported
      conditions = [
        {
          condition = "template";
          value_template = "{{ trigger.id == 'down' or (trigger.to_state.last_changed - trigger.from_state.last_changed).total_seconds() >= 300 }}";
        }
      ];
      actions = [
        {
          choose = [
            {
              conditions = [
                {
                  condition = "trigger";
                  id = "down";
                }
              ];
              sequence =
                notify "facade-openhab" "Facade: openHAB unreachable"
                  "openHAB hasn't answered for 5 minutes. Home Assistant keeps trying every minute.";
            }
          ];
          default =
            notify "facade-openhab" "Facade: openHAB is back"
              "openHAB answers again, after {{ relative_time(trigger.from_state.last_changed) }} without readings.";
        }
      ];
    }

    {
      id = "facade_probe_without_a_reading";
      alias = "Facade: probe without a reading";
      description = "A probe has had no value for 5 minutes (openHAB answers, the probe doesn't).";
      mode = "queued";
      triggers = [
        {
          trigger = "state";
          entity_id = probes;
          to = "unknown";
          for = minutes 5;
        }
      ];
      actions =
        notify "facade-no-reading-{{ trigger.entity_id }}" "Facade: probe without a reading"
          "{{ trigger.to_state.name }} has had no reading for 5 minutes.";
    }

    {
      id = "facade_temperature_out_of_range";
      alias = "Facade: temperature out of range";
      description = "A probe reads above 100 °C or below -100 °C.";
      mode = "queued";
      triggers = [
        {
          trigger = "numeric_state";
          entity_id = probes;
          above = 100;
        }
        {
          trigger = "numeric_state";
          entity_id = probes;
          below = -100;
        }
      ];
      actions =
        notify "facade-range-{{ trigger.entity_id }}" "Facade: temperature out of range"
          "{{ trigger.to_state.name }} reads {{ trigger.to_state.state }} °C, beyond ±100 °C.";
    }

    {
      id = "facade_probe_stuck";
      alias = "Facade: probe stuck";
      description = "The facade probe has read the same value for 30 minutes.";
      triggers = [
        {
          trigger = "state";
          entity_id = facade;
          # Any new value, but not an outage (and not attribute changes)
          not_to = [ "unavailable" "unknown" ];
          for = minutes 30;
        }
      ];
      actions =
        notify "facade-stuck" "Facade: probe stuck?"
          "{{ trigger.to_state.name }} has read {{ trigger.to_state.state }} °C for 30 minutes.";
    }

    {
      id = "facade_colder_than_outside";
      alias = "Facade: colder than outside";
      description = "The facade has been colder than the exterior probe for 5 minutes.";
      triggers = [
        {
          trigger = "template";
          value_template = ''
            {% set f = states('${facade}') | float(none) %}
            {% set e = states('${exterior}') | float(none) %}
            {{ f is not none and e is not none and f < e }}
          '';
          for = minutes 5;
        }
      ];
      actions =
        notify "facade-colder" "Facade: colder than outside"
          "{{ state_attr('${facade}', 'friendly_name') }} reads {{ states('${facade}') }} °C, below the exterior's {{ states('${exterior}') }} °C.";
    }
  ];
}
