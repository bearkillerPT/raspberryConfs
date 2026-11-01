# edapi.bearkillerpt.xyz: the stroke-prediction API behind ed.bearkillerpt.xyz
# (bearkillerPT/DataMining). It trains its models on startup, so it takes a while to answer.
{ inputs, pkgs, ... }:
let
  python = pkgs.python3.withPackages (ps: with ps; [
    flask
    flask-restful
    flask-cors
    pandas
    numpy
    scikit-learn
    imbalanced-learn
    waitress
  ]);

  # The script reads its dataset from a hardcoded ~/DataMining/WebApp/
  app = pkgs.runCommand "edapi" { } ''
    mkdir $out
    cp ${inputs.DataMining}/WebApp/web-api.py ${inputs.DataMining}/WebApp/healthcare-dataset-stroke-data.csv $out/
    substituteInPlace $out/web-api.py --replace-fail '"~/DataMining/WebApp/"' "\"$out/\""
  '';
in
{
  systemd.services.edapi = {
    description = "Data Mining stroke-prediction API";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      # Listens on 0.0.0.0:3003; the firewall keeps it local
      ExecStart = "${python}/bin/python ${app}/web-api.py";
      DynamicUser = true;
      Restart = "on-failure";
    };
  };

  services.nginx.virtualHosts."edapi.bearkillerpt.xyz" = {
    enableACME = true;
    forceSSL = true;
    locations."/".proxyPass = "http://127.0.0.1:3003";
  };
}
