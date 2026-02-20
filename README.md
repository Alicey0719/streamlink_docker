# streamlink_docker
## ex
- compose.yaml
```
services:
  streamlink:
    container_name: streamlink
    image: alicey/streamlink:latest
    volumes: 
      - ./data:/data
    command: ['https://www.tiktok.com/@ao_akase/live', 'best', '--retry-streams', '5', '--retry-max', '30']
```

- k8s manifests
```
{{- range .Values.ytdlSchedule }}
apiVersion: batch/v1
kind: CronJob
metadata:
  name: {{ .name }}
spec:
  schedule: "{{ .schedule }}"
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: streamlink
              image: alicey/streamlink:latest
              args: ['{{ .content }}', 'best', '--retry-streams', '5', '--retry-max', '30']
              volumeMounts:
                - mountPath: /data
                  name: streamlink-storage
          restartPolicy: OnFailure
          volumes:
            - name: streamlink-storage
              persistentVolumeClaim:
                claimName: streamlink-pvc
{{- end }}
```
