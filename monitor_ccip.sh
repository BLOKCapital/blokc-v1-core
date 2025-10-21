#!/bin/bash

# CCIP Fix Monitoring Script
# Run this to continuously monitor results

echo "🔍 CCIP Fix Monitoring Started..."
echo "Monitoring selector: 0xe93e98fd"
echo "Expected facet: 0x4200000000000000000000000000000000000006"
echo ""

# Counter for attempts
attempt=1
max_attempts=20  # Monitor for ~30 minutes (20 attempts x 90 seconds)

while [ $attempt -le $max_attempts ]; do
    echo "📊 Attempt $attempt/$max_attempts ($(date))"
    
    # Run the monitoring script
    cd "/home/aditya/Desktop/Diamond-v3 ccip/blokc-v1-core"
    forge script script/test/MonitorFixResults.s.sol:MonitorFixResults --rpc-url https://base-mainnet.public.blastapi.io | grep -E "(PERFECT|ISSUE|SUCCESS|ERROR|NOT PROCESSED)"
    
    echo "⏰ Waiting 90 seconds for next check..."
    echo "----------------------------------------"
    sleep 90
    
    ((attempt++))
done

echo "🔚 Monitoring completed. Check Base explorer manually for detailed events."
echo "Fixed Receiver: 0x6e22496823F243693cD5718dd8EC0bf531968574"