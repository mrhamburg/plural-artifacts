{{- define "airbyte.sweeper" -}}
#!/bin/bash

get_worker_pods () {
    kubectl -n ${KUBE_NAMESPACE} -L airbyte -l airbyte=worker-pod --field-selector status.phase!=Running get pods -o go-template --template '{{ .Values.podSweeper.podTemplate }}'
}

delete_worker_pod() {
    printf "From status '%s' since '%s', " $2 $3
    echo "$1" | grep -v "STATUS" | awk '{print $1}' | xargs --no-run-if-empty kubectl -n ${KUBE_NAMESPACE} delete pod
}

while :
do
    echo "checking for pods to clean up"
    # Shorter time window for completed pods
    SUCCESS_DATE_STR=`date -d 'now - {{ .Values.podSweeper.timeouts.success }}' --utc -Ins`
    SUCCESS_DATE=`date -d $SUCCESS_DATE_STR +%s`
    # Longer time window for pods in error (to debug)
    NON_SUCCESS_DATE_STR=`date -d 'now - {{ .Values.podSweeper.timeouts.failure }}' --utc -Ins`
    NON_SUCCESS_DATE=`date -d $NON_SUCCESS_DATE_STR +%s`
    (
        IFS=$'\n'
        for POD in `get_worker_pods`; do
            echo $POD
            IFS=' '
            POD_NAME=`echo $POD | cut -d " " -f 1`
            POD_STATUS=`echo $POD | cut -d " " -f 2`
            POD_DATE_STR=`echo $POD | cut -d " " -f 3`
            POD_DATE=`date -d $POD_DATE_STR '+%s'`
            if [ "$POD_STATUS" = "Succeeded" ]; then
            if [ "$POD_DATE" -lt "$SUCCESS_DATE" ]; then
                delete_worker_pod "$POD_NAME" "$POD_STATUS" "$POD_DATE_STR"
            fi
            else
            if [ "$POD_DATE" -lt "$NON_SUCCESS_DATE" ]; then
                delete_worker_pod "$POD_NAME" "$POD_STATUS" "$POD_DATE_STR"
            fi
            fi
        done
    )
    sleep 60
done
{{- end -}}