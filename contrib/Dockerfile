FROM kong/kong:2.7.0

ENV KONG_PLUGINS=bundled,oauth2-token-introspection-request

USER root
RUN luarocks install base64

USER kong
