FROM python:3.11-slim-bullseye

ENV PYTHONUNBUFFERED 1
RUN apt update -y && apt install make

WORKDIR /app

COPY requirements/development.txt requirements/development.txt
RUN pip install -r requirements/development.txt
