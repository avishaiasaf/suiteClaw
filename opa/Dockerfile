FROM openpolicyagent/opa:latest

COPY policies/ /policies/
COPY data/ /data/

EXPOSE 8181

CMD ["run", "--server", "--log-level", "info", "--addr", ":8181", "/policies/", "/data/"]
