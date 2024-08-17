terraform {
  required_version = ">= 1.8.0"
  required_providers {
    assert = {
      source  = "hashicorp/assert"
      version = "0.11.1"
    }
  }
}

locals {
  mac_address = var.mac_address
  ipv6_prefix = var.ipv6_prefix

  # Extract the network portion of the IPv6 prefix
  network_prefix = split("/", local.ipv6_prefix)[0]

  mac_parts = split(":", local.mac_address)

  # Correct EUI-64 modification: Flip the 7th bit of the first byte
  first_byte_dec = parseint(local.mac_parts[0], 16)
  seventh_bit    = (local.first_byte_dec / 2) % 2 # Extract the 7th bit (0 or 1)

  # If 7th bit is 0, add 2 to set it to 1
  # If 7th bit is 1, subtract 2 to set it to 0
  modified_first_byte_dec = local.seventh_bit == 0 ? local.first_byte_dec + 2 : local.first_byte_dec - 2
  modified_first_byte     = format("%02x", local.modified_first_byte_dec)

  eui64_identifier = join("", [
    local.modified_first_byte,
    local.mac_parts[1],
    local.mac_parts[2],
    "ff",
    "fe",
    local.mac_parts[3],
    local.mac_parts[4],
    local.mac_parts[5]
  ])

  # Convert EUI-64 identifier to IPv6 interface identifier format
  ipv6_interface_identifier = format("%s:%s:%s:%s",
    substr(local.eui64_identifier, 0, 4),
    substr(local.eui64_identifier, 4, 4),
    substr(local.eui64_identifier, 8, 4),
    substr(local.eui64_identifier, 12, 4)
  )

  # Combine IPv6 prefix with EUI-64 interface identifier
  ipv6_address = "${local.network_prefix}:${local.ipv6_interface_identifier}"

  replace_zero_groups    = replace(local.ipv6_address, "/:(0000:)+/", ":")
  replace_leading_zeroes = replace(local.replace_zero_groups, "/:0+/", ":")

  ipv6_eui64_address_shortened = replace(local.replace_leading_zeroes, "/::+/", "::")
}

check "ipv6_eui64_address_shortened_valid" {
  assert {
    condition     = provider::assert::ipv6(local.ipv6_eui64_address_shortened)
    error_message = "Resulting IPv6 is not valid, must be klingons..."
  }
}

variable "mac_address" {
  description = "The MAC address to use"
  type        = string
  default     = "02:00:00:00:00:01"
}

variable "ipv6_prefix" {
  description = "The IPv6 prefix to use"
  validation {
    condition     = provider::assert::ipv6(split("/", var.ipv6_prefix)[0])
    error_message = "Invalid IPv6 address"
  }
  type        = string
  default     = "2001:db8::/64"
}

output "eui64" {
  description = "EUI-64 identifier"
  value       = local.eui64_identifier
}

output "ipv6_eui64_address" {
  description = "Shortened IPv6 EUI-64 address"
  value       = local.ipv6_eui64_address_shortened
}
