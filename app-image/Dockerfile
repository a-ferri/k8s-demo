FROM python:3.8-alpine

ENV PATH="/home/app/.local/bin:${PATH}"

RUN adduser -D app
USER app

WORKDIR /app

COPY sample/requirements.txt .
COPY sample/app.py .

RUN pip3 install -r requirements.txt

ENTRYPOINT ["flask", "run", "--host=0.0.0.0"]