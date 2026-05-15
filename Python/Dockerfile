
FROM python:3.7

RUN pip install pipenv

COPY Pipfile Pipfile
COPY Pipfile.lock Pipfile.lock

# Add the external tasks directory into /tasks
ADD config.py /queloader/config.py
ADD publish_create.py /queloader/publish_create.py
ADD publish_cancel.py /queloader/publish_cancel.py
ADD publish_update.py /queloader/publish_update.py
ADD testFiles.py /queloader/testFiles.py

# Install the required dependencies via pip
RUN pipenv install --deploy --system
RUN pipenv install pika

WORKDIR "/queloader"

# Start Container 
ENTRYPOINT ["sleep", "infinity"]