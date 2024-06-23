server {
    root /home/ubuntu/zero_wait/build;

    index index.html;

    server_name crm.hoterway.com;

    location / {
      try_files $uri $uri/ /index.html;
    }


    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/crm.hoterway.com/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/crm.hoterway.com/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

}

server {
    if ($host = crm.hoterway.com) {
        return 301 https://$host$request_uri;
    }

    server_name crm.hoterway.com;
    listen 80;
    return 404;
}

server {
    if ($host = crm.hoterway.com) {
        return 301 https://$host$request_uri;
    } # managed by Certbot



    server_name crm.hoterway.com;
    listen 80;
    return 404; # managed by Certbot


}