$env:AZCOPY_SPA_CLIENT_SECRET="<secret>"
azcopy login --service-principal --application-id "<app id>" --tenant-id "<tenant id>"
azcopy copy "test-file1.txt" "https://stsbusinesscentralsa.blob.core.windows.net/businesscentral"