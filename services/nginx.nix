# Shared nginx and Let's Encrypt setup. Each service file declares its own virtual host
# with `enableACME` + `forceSSL`: one certificate per site, renewed by systemd timers.
{
  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;

    # The DNS records are wildcards, so unknown names (mostly bots) land here
    virtualHosts."_" = {
      default = true;
      rejectSSL = true;
      locations."/".return = "444";
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "gilteixeira@ua.pt";
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
