
set dotenv-load
WIFI_SSID := env_var_or_default("WIFI_SSID", "")
WIFI_PASS := env_var_or_default("WIFI_PASS", "")
LEADER_PORT := "3000"
OTA_PORT := "8080"

[group('setup')]
setup:
    rustup target add thumbv7em-none-eabihf riscv32imc-unknown-none-elf mips-unknown-linux-musl
    cargo install probe-rs --features cli || true
    cargo install espflash cargo-binutils just || true
    cargo install cross --git https://github.com/cross-rs/cross || true
    rustup component add llvm-tools-preview

[group('setup')]
keys:
    #!/bin/bash
    if [ ! -f cluster_pubkey.bin ]; then
        cargo run --release -p masterstack-leader --bin gen_keypair
        echo "Keys generated"
    else
        echo "Keys exist"
    fi

[group('build')]
build-all: keys
    cargo build --release -p masterstack-universal --target thumbv7em-none-eabihf --features cortex-m4 --no-default-features
    cargo build --release -p masterstack-universal --target riscv32imc-unknown-none-elf --features esp32c3 --no-default-features
    cross build --release -p masterstack-universal --target mips-unknown-linux-musl --features host
    cargo build --release -p masterstack-universal --features host
    cargo build --release -p masterstack-leader --features host
    @echo "All 4 targets built"

[group('build')]
size-check: build-all
    @.github/scripts/size_guard.sh target/thumbv7em-none-eabihf/release/masterstack-universal

[group('flash')]
flash-both SSID PASS: keys build-all
    #!/bin/bash
    set -e
    echo "Flashing STM32 + ESP32-C3 with WiFi: {{SSID}}"
    python3 -c "import struct; ssid=b'{{SSID}}'.ljust(32,b'\x00'); pw=b'{{PASS}}'.ljust(64,b'\x00'); open('wifi_creds.bin','wb').write(ssid+pw+struct.pack('<I',0x57494649))"
    (probe-rs download --chip STM32F401RE target/thumbv7em-none-eabihf/release/masterstack-universal --format elf && probe-rs download --chip STM32F401RE cluster_pubkey.bin --format bin --base-address 0x0807F800 && echo "[STM32] OK") &
    (espflash write-bin 0x320000 cluster_pubkey.bin && espflash write-bin 0x321000 wifi_creds.bin && cargo espflash flash --partition-table partitions_ota.csv --release -p masterstack-universal --target riscv32imc-unknown-none-elf --features esp32c3 --no-default-features && echo "[ESP32] OK") &
    wait

[group('fleet')]
leader:
    cargo run --release -p masterstack-leader -- --secret cluster_secret.key --swarm config/llm_swarm.toml --mdns --ota --port {{LEADER_PORT}}

[group('fleet')]
leader-watch:
    cargo run --release -p masterstack-leader -- --secret cluster_secret.key --swarm config/llm_swarm.toml --mdns --ota --watch

[group('fleet')]
logs-stm32:
    probe-rs attach --chip STM32F401RE target/thumbv7em-none-eabihf/release/masterstack-universal

[group('fleet')]
logs-esp:
    espflash monitor --baud 115200

[group('ota')]
ota-push: build-all
    #!/bin/bash
    cp target/riscv32imc-unknown-none-elf/release/masterstack-universal ota_cache/firmware.bin
    curl -X POST http://localhost:{{OTA_PORT}}/ota/bump-version || echo "Restart leader"

[group('test')]
test-all:
    cargo test --release -p masterstack-universal --features host
    cargo test --release -p masterstack-leader --features host

[group('test')]
miri:
    cargo miri test -p masterstack-universal --features host --lib

[group('default')]
default:
    @just --list --unsorted
