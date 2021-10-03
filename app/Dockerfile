FROM python:3.9.7-slim

ENV FLASK_ENV development

WORKDIR /app

RUN apt update && apt install -y net-tools dnsutils telnet

ADD . .
RUN pip install -r requirements.txt

ENTRYPOINT ["python", "/app/app.py"]
