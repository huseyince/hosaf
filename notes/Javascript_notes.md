```bash
cat domains | katana | grep js | httpx -mc 200 | tee js_files

for js_file in `cat js_files`; do curl $js_file | grep -E "aws_access_key|aws_secret_key|api key|passwd|pwd|heroku|slack|firebase|swagger|aws_secret_key|aws key|password|ftp password|jdbc|db|sql|secret jet|config|admin|pwd|json|gcp|htaccess|.env|ssh key|.git|access key|secret token|oauth_token|oauth_token_secret|smtp" | tee js_out; done
```
