#!/bin/bash

CONFIG_DIR="$HOME/.config/pin"
DB_DIR="$CONFIG_DIR/database"
CONFIG_FILE="$CONFIG_DIR/config"
DEFAULT_DB="pin_default"

# ANSI Colors
YELLOW="\033[1;33m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
MAGENTA="\033[0;35m"
RESET="\033[0m"

mkdir -p "$DB_DIR"

# Initialize default DB if none exists
if ! ls "$DB_DIR"/*.json &>/dev/null; then
    echo "[]" > "$DB_DIR/$DEFAULT_DB.json"
    echo "$DEFAULT_DB" > "$CONFIG_FILE"
    echo "🛠️  Default database '$DEFAULT_DB' created and selected."
fi

get_selected_db() {
    if [[ -f "$CONFIG_FILE" ]]; then
        cat "$CONFIG_FILE"
    else
        echo "$DEFAULT_DB"
    fi
}

show_help() {
    figlet pin
    echo "📌 pin - A simple personal text database manager"
    echo ""
    echo "Usage:"
    echo "  pin add <text>            Add text to selected database"
    echo "  pin rip <id>              Remove text entry by ID"
    echo "  pin create_db <name>      Create a new database"
    echo "  pin select_db <name>      Select a database"
    echo "  pin list_db               List all databases"
    echo "  pin help                  Show this help message"
    echo "  pin                       Show all entries in selected database"
}

case "$1" in
    add)
        shift
        TEXT="$*"
        DB=$(get_selected_db)
        DB_PATH="$DB_DIR/$DB.json"
        if [[ -z "$DB" ]]; then
            echo "⚠️ No database selected. Use 'pin database <name>' to select one."
            exit 1
        fi
        [[ ! -f "$DB_PATH" ]] && echo "[]" > "$DB_PATH"
        ID=$(jq '.[].id' "$DB_PATH" 2>/dev/null | sort -n | tail -1)
        ID=$((ID + 1))
        jq ". += [{\"id\": $ID, \"text\": \"$TEXT\"}]" "$DB_PATH" > "$DB_PATH.tmp" && mv "$DB_PATH.tmp" "$DB_PATH"
        echo "✅ Added with ID: $ID"
        ;;

    rip)
        shift
        ID="$1"
        DB=$(get_selected_db)
        DB_PATH="$DB_DIR/$DB.json"
        if [[ -z "$DB" || ! -f "$DB_PATH" ]]; then
            echo "⚠️ No database selected or it doesn't exist."
            exit 1
        fi
        TMP_FILE=$(mktemp)
        jq "del(.[] | select(.id == $ID))" "$DB_PATH" > "$TMP_FILE" && mv "$TMP_FILE" "$DB_PATH"
        echo "🗑️ Entry with ID $ID removed."
        ;;

    create_db)
        shift
        DB_NAME="$1"
        DB_PATH="$DB_DIR/$DB_NAME.json"
        if [[ -f "$DB_PATH" ]]; then
            echo "⚠️ Database '$DB_NAME' already exists."
        else
            echo "[]" > "$DB_PATH"
            echo "✅ Database '$DB_NAME' created."
        fi
        ;;

    select_db)
        shift
        DB_NAME="$1"
        if [[ -f "$DB_DIR/$DB_NAME.json" ]]; then
            echo "$DB_NAME" > "$CONFIG_FILE"
            echo "✅ Database '$DB_NAME' selected."
        else
            echo "⚠️ Database '$DB_NAME' does not exist. Use 'pin create_db $DB_NAME' to create it."
        fi
        ;;

    list_db)
        echo "📂 Available databases:"
        CURRENT_DB=$(get_selected_db)
        for file in "$DB_DIR"/*.json; do
            DB_NAME=$(basename "$file" .json)
            TAGS=""
            [[ "$DB_NAME" == "$DEFAULT_DB" ]] && TAGS+=" <default>"
            [[ "$DB_NAME" == "$CURRENT_DB" ]] && TAGS+=" <selected>"
            echo "$DB_NAME$TAGS"
        done
        ;;

    help)
        show_help
        ;;

    "")
        DB=$(get_selected_db)
        DB_PATH="$DB_DIR/$DB.json"

        if [[ -z "$DB" || ! -f "$DB_PATH" ]]; then
            echo -e "${YELLOW}⚠️ No database selected or it doesn't exist.${RESET}"
            exit 1
        fi

        COUNT=$(jq length "$DB_PATH")
        if [[ "$COUNT" -eq 0 ]]; then
            echo -e "${YELLOW}📋 No entries found in '$DB'.${RESET}"
            exit 0
        fi

        echo ""
        echo -e "${YELLOW}📋 Showing entries from database:${RESET}  ${CYAN}[$DB]${RESET}"
        echo -e "${CYAN}-------------------------------------------${RESET}"
        printf "${CYAN}%-5s | %s${RESET}\n" "ID" "Text"
        echo -e "${CYAN}-------------------------------------------${RESET}"

        jq -r '.[] | "\(.id)\t\(.text)"' "$DB_PATH" | while IFS=$'\t' read -r ID TEXT; do
            printf "${GREEN}%-5s${RESET} | %s\n" "$ID" "$TEXT"
        done

        echo -e "${CYAN}-------------------------------------------${RESET}"
        echo -e "${MAGENTA}🧾 Total entries: $COUNT${RESET}"
        echo ""
        ;;


    *)
        echo "❌ Unknown command: $1"
        show_help
        ;;
esac
