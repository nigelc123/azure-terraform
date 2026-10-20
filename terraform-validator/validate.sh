#!/bin/bash

# Terraform Validation Pipeline
# Runs formatting, syntax and policy checks against Terraform configurations.

# Colour codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Create two indexed arrays to store the name of each check, and its result.
declare -a CHECK_NAMES
declare -a CHECK_RESULTS

# Create two variables to hold the count of total passes and fails.
TOTAL_PASS=0
TOTAL_FAIL=0

trap 'rm -f tfplan tfplan.json' EXIT

print_header() {
    echo ""
    echo -e "${BLUE}=======================================${RESET}"
    echo -e "${BLUE}Terraform Validation Pipeline${RESET}"
    echo -e "${BLUE}=======================================${RESET}"
    echo ""

    sleep 1.5
}

# Prints 'PASS' in the defined green colour, and resets it back to the default colour for the ':'
print_pass() {
    echo -e "${GREEN}PASS${RESET}: $1" # '-e' allows interpretation of escape characters, so colour codes work (since they contain backslashes).
}

# Prints 'FAIL' in the defined red colour, and resets it back to the default colour for the ':'
print_fail() {
    echo -e "${RED}FAIL${RESET}: $1"
}

# Prints 'WARNING' in the defined yellow colour, and resets is back to the default colour for the ':'
print_warning() {
    echo -e "${YELLOW}WARNING${RESET}: $1"
}

print_skip() {
    echo -e "   ${YELLOW}SKIP${RESET}: $1"
}

record_result() {
    local name="$1"
    local result="$2"
    CHECK_NAMES+=("$name")
    CHECK_RESULTS+=("$result")

    if [ "$result" = "PASS" ]; then
        TOTAL_PASS=$((TOTAL_PASS + 1))
    else
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
    fi
}

check_formatting () {
    echo -e "${BLUE}[1/3] Checking formatting...${RESET}"
    sleep 1.5s

    # If the result of terraform fmt -check -recursive returns an exit code of 0 (success, formatting is correct), this section runs.
    # -check is used to check if input is formatted correctly, but doesn't make changes. Exit status is 0 if properly formatted.
    # This discards all output (STDOUT and STDERR) to /dev/null.
    if terraform fmt -check -recursive > /dev/null 2>&1; then
        print_pass "Formatting check passed!"
        record_result "Formatting" "PASS"
        return 0
    else # If the check fails, the below runs.
        local unformatted # Create a local variable called 'unformatted'
        unformatted=$(terraform fmt -check -recursive 2>/dev/null) # Run the command again
        print_fail "Formatting check failed."
        echo "  Files needing formatting:"

        # Loop through the filenames and print it out as a bullet point, if the file needs formatting.
        echo "$unformatted" | while IFS= read -r file; do
            echo "  - $file"
        done

        record_result "Formatting" "FAIL"
        return 1
    fi
}

check_syntax() {
    echo ""
    echo -e "${BLUE}[2/3] Validating syntax...${RESET}"

    local validate_output # Create a local variable validate_output.
    validate_output=$(terraform validate -json 2>&1) # Store the output of the command in the local variable.

    local is_valid # Create a local variable is_valid.
    is_valid=$(echo "$validate_output" | jq -r '.valid') # Prints the output of $validate_output, piped through jq to extract the 'valid' field output by terraform validate -json. -r extracts raw strings without quotes.

    local error_count # Create a local variable error_count.
    error_count=$(echo "$validate_output" | jq -r '.error_count') # Prints the output of $validate_output, piped through jq to extract the 'error_count' field output by terraform validate -json

    local warning_count # Create a local variable warning_count.
    warning_count=$(echo "$validate_output" | jq -r '.warning_count') # Prints the output of $validate_output, piped through jq to extract the 'warning_count' field output by terraform validate -json

    # The 'valid' field is either true or false. If true, the configuration is valid and no changes need to be made. Validation passes.
    if [ "$is_valid" = "true" ]; then
        print_pass "Validation passed (0 errors, $warning_count warnings)"
        record_result "Syntax" "PASS"
        return 0
    else # Otherwise, the validation is not valid and changes need to be made. Use jq to extract the 'diagnostics' field and select those with severity 'error' and print the summary and detail for each.
        print_fail "Validation found $error_count error(s)" # Print validation failed, with the count of errors.

        # Prints the output of terraform validate -json, filter for the 'diagnostics' field and select those with severity 'error'.
        # Pipe this to provide useful information about where the error is located, the summary of the error and the detail of the error.
        echo "$validate_output" | jq -r '.diagnostics[] | select (.severity == "error") | "     - In \(.range.filename) at line \(.range.start.line): \(.summary): \(.detail // "no details")"'
        
        record_result "Syntax" "FAIL"
        return 1 # Return exit code of 1.
    fi
}

check_plan() {
    echo ""
    echo -e "${BLUE}[3/3] Running plan policy checks...${RESET}"

    # Generate a plan file and suppress the output by sending to /dev/null.
    # If the terraform plan does not generate successfully (checked using the !, if the exit code is not 0 then is is unsuccessful)
    if ! terraform plan -out=tfplan -input=false > /dev/null 2>&1; then
        print_fail "Terraform plan failed to generate."
        record_result "Plan Policy" "FAIL"
        return 1
    fi

    # Convert the binary plan to JSON for parsing, the tfplan file is binary by default.
    # Write the json version to a new file called tfplan.json, and redirect errors to /dev/null.
    terraform show -json tfplan > tfplan.json 2>/dev/null

    local delete_count # Create a local variable to hold the count of deletions. Used in the if statement later.

    # Use jq to parse through the resource_changes block of tfplan.json to find those with the change action delete.
    # Pipe this into length to find the count of resource deletions.
    delete_count=$(jq '[.resource_changes[] | select(.change.actions[] == "delete")] | length' tfplan.json)

    # The way the script is stuctured means that if there is a single deletion found, we don't get a summary of the creations and updates.
    # This is an intentional decision for a fail-fast script, as in this scenario we only really care about potential destructive changes — so we want them flagged straight away.
    if [ "$delete_count" -gt 0 ]; then
        print_warning "Plan includes $delete_count resource deletion(s). Please verify correctness before applying the plan."
        echo "      Resources to be deleted:"
        jq -r '.resource_changes[] | select(.change.actions[] == "delete") | "          - \(.address)"' tfplan.json

        record_result "Plan Policy" "FAIL"
        return 1
    else
        local create_count # Create a local variable to hold the count of creations.

        # Use jq to parse through the resource_changes block of tfplan.json to find those with the change action create.
        # Pipe this into length to find the count of resource creations.
        create_count=$(jq '[.resource_changes[] | select(.change.actions[] == "create")] | length' tfplan.json)
        
        local update_count# Create a local variable to hold the count of creations.

        # Use jq to parse through the resource_changes block of tfplan.json to find those with the change action update.
        # Pipe this into length to find the count of resource updates.
        update_count=$(jq '[.resource_changes[] | select(.change.actions[] == "update")] | length' tfplan.json)
        print_pass "No destructive changes detected. This plan creates $create_count and updates $update_count resources."
        
        record_result "Plan Policy" "PASS"
        return 0
    fi
}

print_summary() {
  echo ""
  echo -e "${BLUE}========================================${RESET}"
  echo -e "${BLUE}Summary${RESET}"
  echo -e "${BLUE}========================================${RESET}"
  echo ""

  for i in "${!CHECK_NAMES[@]}"; do
    local status="${CHECK_RESULTS[$i]}"
    if [ "$status" = "PASS" ]; then
      echo -e "  ${GREEN}PASS${RESET}  ${CHECK_NAMES[$i]}"
    elif [ "$status" = "SKIP" ]; then
      echo -e "  ${YELLOW}SKIP${RESET}  ${CHECK_NAMES[$i]}"
    else
      echo -e "  ${RED}FAIL${RESET}  ${CHECK_NAMES[$i]}"
    fi
  done

  echo ""
  echo -e "  Results: ${GREEN}$TOTAL_PASS passed${RESET}, ${RED}$TOTAL_FAIL failed${RESET}"
  echo ""

  if [ "$TOTAL_FAIL" -gt 0 ]; then
    echo -e "  ${RED}Validation failed!${RESET}"
    return 1
  else
    echo -e "  ${GREEN}All checks passed!${RESET}"
    return 0
  fi
}

print_header
check_formatting
check_syntax
check_plan
print_summary
exit $?