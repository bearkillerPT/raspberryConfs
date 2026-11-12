# Solar: the Huawei inverter (SUN2000-2KTL-L1) and the power meter behind it, added in the UI
# (huawei-solar.nix packages the integration). The meter counts export as positive, so its
# raw watts read backwards on a dashboard; these two sensors say it plainly:
#   Home power: what the house uses now (solar output minus what goes to the grid)
#   Grid power: positive while buying from the grid, negative while selling
# The Energy tab is set up in the UI (Settings → Dashboards → Energy).
{ ... }:
let
  solar = "sensor.inverter_active_power";
  meter = "sensor.power_meter_active_power";
  power = name: id: icon: state: {
    inherit name icon state;
    unique_id = id;
    device_class = "power";
    state_class = "measurement";
    unit_of_measurement = "W";
    # The inverter sleeps at night; the meter is what has to answer
    availability = "{{ has_value('${meter}') }}";
  };
in
{
  services.home-assistant.config.template = [
    {
      sensor = [
        (power "Home power" "home_power" "mdi:home-lightning-bolt"
          "{{ (states('${solar}') | float(0) - states('${meter}') | float) | round(0) | int }}")
        (power "Grid power" "grid_power" "mdi:transmission-tower"
          "{{ (0 - states('${meter}') | float) | round(0) | int }}")
      ];
    }
  ];
}
