#!/bin/sh -eu

su www-data -s /opt/domjudge/domserver/webapp/bin/console cache:clear &
