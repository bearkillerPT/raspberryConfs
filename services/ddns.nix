# Keeps the Namecheap records (both domains, including the wildcards) on the home IP.
{ config, ... }:
{
  services.ddclient = {
    enable = true;
    configFile = config.sops.templates."ddclient.conf".path;
  };

  sops.secrets."ddns/bearkillerpt.xyz" = { };
  sops.secrets."ddns/plughere.app" = { };
  sops.templates."ddclient.conf".content = ''
    usev4=webv4, webv4=ipify-ipv4
    ssl=yes
    protocol=namecheap
    server=dynamicdns.park-your-domain.com

    login=bearkillerpt.xyz
    password=${config.sops.placeholder."ddns/bearkillerpt.xyz"}
    @.bearkillerpt.xyz,*.bearkillerpt.xyz,www.bearkillerpt.xyz

    login=plughere.app
    password=${config.sops.placeholder."ddns/plughere.app"}
    @.plughere.app,*.plughere.app
  '';
}
