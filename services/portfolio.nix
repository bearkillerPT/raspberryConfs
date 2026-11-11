# bearkillerpt.xyz: static build of bearkillerPT/repos-website (Vite + bun), built by that repo's
# own flake. When its bun.lock changes, the hash in its nix/package.nix changes with it.
{ inputs, pkgs, ... }:
let
  site = inputs.repos-website.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  services.nginx.virtualHosts."bearkillerpt.xyz" = {
    serverAliases = [ "www.bearkillerpt.xyz" ];
    enableACME = true;
    forceSSL = true;
    root = site;
    # Unknown addresses get the site's own "page not found" instead of nginx's
    extraConfig = ''
      error_page 404 /404.html;
    '';
    # The CV used to live here; old links (LinkedIn, emails) go to the one built with the site
    locations."= /Curriculo.pdf".return = "301 /cv.pdf";
    # Vite puts a content hash in every file name under /assets, so they never change
    locations."/assets/".extraConfig = ''
      expires 1y;
      add_header Cache-Control "public, immutable";
    '';
  };
}
