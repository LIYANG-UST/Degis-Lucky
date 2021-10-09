env=rinkeby
sleep_time1=5400
sleep_time2=300
sleep_time3=60

truffle migrate --network $env  --reset
sleep $sleep_time3; npx truffle exec scripts/DegisLottery/01_init.js --network $env
sleep $sleep_time3; npx truffle exec scripts/DegisLottery/02_start-lottery.js --network $env
sleep $sleep_time3; npx truffle exec scripts/DegisLottery/03_inject-funds.js --network $env
sleep $sleep_time3; npx truffle exec scripts/DegisLottery/04_buy-tickets.js --network $env
sleep $sleep_time3; npx truffle exec scripts/DegisLottery/05_redeem-tickets.js --network $env
sleep $sleep_time1; npx truffle exec scripts/DegisLottery/06_close-lottery.js --network $env
sleep $sleep_time2; npx truffle exec scripts/DegisLottery/07_draw.js --network $env
sleep $sleep_time3; npx truffle exec scripts/DegisLottery/08_claim.js --network $env
sleep $sleep_time3; npx truffle exec scripts/DegisLottery/09_start-lottery.js --network $env
sleep $sleep_time3; npx truffle exec scripts/DegisLottery/10_inject-funds.js --network $env
sleep $sleep_time3; npx truffle exec scripts/DegisLottery/11_buy-tickets.js --network $env
sleep $sleep_time3; npx truffle exec scripts/DegisLottery/12_redeem-tickets.js --network $env
sleep $sleep_time1; npx truffle exec scripts/DegisLottery/13_close-lottery.js --network $env
sleep $sleep_time2; npx truffle exec scripts/DegisLottery/14_draw.js --network $env
sleep $sleep_time3; npx truffle exec scripts/DegisLottery/15_claim.js --network $env
