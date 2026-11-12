# Huawei Solar (github.com/wlcrs/huawei_solar): reads the Huawei SUN2000 inverter, and a battery or
# power meter behind it, locally over Modbus TCP. Neither it nor its libraries are in nixpkgs.
#
# 2.1.2 is the last release that runs on Home Assistant before 2026.8 (nixos-26.05 ships 2026.5).
# The libraries are the versions people ran with it: huawei-solar 3.0.7 and tmodbus 0.6.x
# (tmodbus 1.0 came later). Move all three up together with nixpkgs.
{
  home-assistant,
  buildHomeAssistantComponent,
  fetchFromGitHub,
  fetchPypi,
}:
let
  python = home-assistant.python3Packages;

  tmodbus = python.buildPythonPackage rec {
    pname = "tmodbus";
    version = "0.6.2";
    pyproject = true;
    src = fetchPypi {
      inherit pname version;
      hash = "sha256-Tfdb85dvMtdIHuQ/kfT4uj5pBTFcqj8Tdr5AJPmH1qQ=";
    };
    build-system = with python; [ hatchling hatch-vcs ];
    env.SETUPTOOLS_SCM_PRETEND_VERSION = version;
    # With the async-serial extra, which huawei-solar asks for
    dependencies = with python; [ tenacity serialx ];
    pythonImportsCheck = [ "tmodbus" ];
  };

  huawei-solar = python.buildPythonPackage rec {
    pname = "huawei-solar";
    version = "3.0.7";
    pyproject = true;
    src = fetchPypi {
      pname = "huawei_solar";
      inherit version;
      hash = "sha256-KZdupobKU8BV75nHXhStP+DGkra/g2KmFpXWerbbUwQ=";
    };
    build-system = with python; [ hatchling hatch-vcs ];
    env.SETUPTOOLS_SCM_PRETEND_VERSION = version;
    dependencies = [ tmodbus ];
    pythonImportsCheck = [ "huawei_solar" ];
  };
in
buildHomeAssistantComponent rec {
  owner = "wlcrs";
  domain = "huawei_solar";
  version = "2.1.2";
  src = fetchFromGitHub {
    owner = "wlcrs";
    repo = "huawei_solar";
    tag = version;
    hash = "sha256-fzQLeyKcIYOJk3cZm8HTG8RcURO3UYpcC1S5rw+QhNo=";
  };
  dependencies = [ huawei-solar ];
}
