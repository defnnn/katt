FROM python:3.9.7-slim

ARG flask_env=production

ENV FLASK_ENV $flask_env

WORKDIR /app

ADD requirements.txt .
RUN pip install -r requirements.txt

ADD app.py now.py start-time.txt .

ADD index.html templates/index.html

RUN pwd
RUN ls -ld *
RUN id -a

ENTRYPOINT ["python", "/app/app.py"]
