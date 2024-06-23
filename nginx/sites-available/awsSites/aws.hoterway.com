server {
    root /home/ubuntu/audit_waiting/build;

    index index.html;

    server_name aws.hoterway.com;

    location / {
      try_files $uri $uri/ /index.html;
    }


    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/aws.hoterway.com/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/aws.hoterway.com/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

}

server {
    if ($host = aws.hoterway.com) {
        return 301 https://$host$request_uri;
    }

    server_name aws.hoterway.com;
    listen 80;
    return 404;
}

server {
    if ($host = aws.hoterway.com) {
        return 301 https://$host$request_uri;
    } # managed by Certbot



    server_name aws.hoterway.com;
    listen 80;
    return 404; # managed by Certbot


}