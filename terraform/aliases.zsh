if (( ! $+commands[terraform] )); then
  return
fi

# If the completion file doesn't exist yet, we need to autoload it and
# bind it to `terraform`. Otherwise, compinit will have already done that.
# terraform -install-autocomplete

alias tf='terraform'
alias tfa='terraform apply'
alias tfc='terraform console'
alias tfd='terraform destroy'
alias tff='terraform fmt'
alias tfi='terraform init'
alias tfo='terraform output'
alias tfp='terraform plan'
alias tfv='terraform validate'
alias tfs='terraform state'
alias tft='terraform test'
alias tfsh='terraform show'
