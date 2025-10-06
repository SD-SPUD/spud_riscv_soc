#!/bin/bash
# setup_env.sh: configure SystemC and Verilator paths interactively

echo "🔧 SPUD setup script"
read -p "Enter your SystemC installation path (e.g., /home/you/systemc-2.3.3): " SYSTEMC_HOME
read -p "Enter your Verilator installation path (e.g., /home/you/verilator-3.890): " VERILATOR_HOME

# Update environment variables file
cat > .env <<EOL
SYSTEMC_HOME=$SYSTEMC_HOME
VERILATOR_HOME=$VERILATOR_HOME
EOL

echo "✅ Saved paths to .env"
echo "You can now build with: make SYSTEMC_HOME=$SYSTEMC_HOME VERILATOR_HOME=$VERILATOR_HOME"

