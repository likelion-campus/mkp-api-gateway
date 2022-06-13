FROM kong/kong:2.7.0

ENV KONG_PLUGINS=bundled,hello-world

COPY ./src/hello-world /usr/local/share/lua/5.1/kong/plugins/hello-world
