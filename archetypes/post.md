---
{{- $slug := replaceRE "\\d{4}-\\d{2}-\\d{2}-(.+)" "$1" .Name }}
title: "{{ replace $slug "-" " " | title }}"
date: {{ .Date }}
author: urandom
tags:
slug: "{{ $slug }}"
draft: true
---
