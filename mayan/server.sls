{% from "mayan/map.jinja" import server with context %}

{%- if server.enabled %}

include:
- git

mayan_packages:
  pkg.installed:
  - names: {{ server.pkgs }}

/srv/mayan:
  virtualenv.manage:
  - system_site_packages: False
  - requirements: salt://mayan/conf/requirements.txt
  - require:
    - pkg: mayan_packages
    - pkg: git_packages

mayan_user:
  user.present:
  - name: mayan
  - system: True
  - shell: /bin/sh
  - home: /srv/mayan
  - require:
    - virtualenv: /srv/mayan

mayan_dirs:
  file.directory:
  - names:
    - /srv/mayan/static
    - /srv/mayan/media
    - /srv/mayan/logs
    - /srv/mayan/site
    - /srv/mayan/document_storage
    - /srv/mayan/document_storage/document_storage
    - /srv/mayan/document_storage/image_cache
    - /srv/mayan/document_storage/gpg_home
    {%- if server.storage_location is defined %}
    - {{ server.storage_location }}
    {%- endif %}
  - user: mayan
  - group: mayan
  - mode: 660
  - makedirs: true
  - require:
    - virtualenv: /srv/mayan

{{ server.source.address }}:
  git.latest:
  - target: /srv/mayan/app
  - rev: {{ server.source.rev }}
  - require:
    - virtualenv: /srv/mayan
    - pkg: git_packages
  - require_in:
    - file: app_dirs


app_dirs:
  file.directory:
  - names:
    - /srv/mayan/gpg_home
    - /srv/mayan/document_storage
    - /srv/mayan/site
  - user: mayan
  - group: mayan
  - mode: 777
  - makedirs: true
  - require:
    - virtualenv: /srv/mayan

/srv/mayan/bin/gunicorn_start:
  file.managed:
  - source: salt://mayan/conf/gunicorn_start
  - mode: 700
  - user: mayan
  - group: mayan
  - template: jinja
  - require:
    - virtualenv: /srv/mayan

/srv/mayan/site/manage.py:
  file.managed:
  - source: salt://mayan/conf/manage.py
  - template: jinja
  - mode: 755
  - require:
    - git: {{ server.source.address }}
    - file: app_dirs

/srv/mayan/site/local_settings.py:
  file.managed:
  - source: salt://mayan/conf/settings.py
  - template: jinja
  - mode: 644
  - require:
    - file: /srv/mayan/site/manage.py

/srv/mayan/site/wsgi.py:
  file.managed:
  - source: salt://mayan/conf/server.wsgi
  - template: jinja
  - mode: 644
  - require:
    - file: /srv/mayan/site/local_settings.py

mayan_sync_database:
  cmd.run:
  - name: source /srv/mayan/bin/activate; python manage.py syncdb --noinput
  - cwd: /srv/mayan/site

mayan_migrate_database:
  cmd.run:
  - name: source /srv/mayan/bin/activate; python manage.py migrate
  - cwd: /srv/mayan/site
  - require:
    - cmd: mayan_sync_database

mayan_collect_static:
  cmd.run:
  - name: source /srv/mayan/bin/activate; python manage.py collectstatic --noinput
  - cwd: /srv/mayan/site
  - require:
    - cmd: mayan_migrate_database
    - file: /srv/mayan/static

mayan_web_service:
  supervisord.running:
  - names:
    - mayan_server
  - restart: True
  - user: root

{%- endif %}