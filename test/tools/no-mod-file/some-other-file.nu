#!/usr/bin/env nu

# This directory has .nu files but no mod.nu file
# It should be ignored by the new discovery system

def main [] {
    "This should not be discovered"
}