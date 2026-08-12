variable "project-name" {
  type        = string
  description = "Short descriptor of the project."

  validation {
    condition     = can(regex("^[a-z][a-z]{2,14}", var.project-name))
    error_message = "Project Name must be 3-15 lowercase letters, with no numbers."
  }
}


variable "ssh_public_key_path" {
  type        = string
  description = "Path to the SSH public key used to log into the VM."
  default     = "~/.ssh/id_rsa.pub" # Use ssh-keygen to generate this before activating this lab.
}