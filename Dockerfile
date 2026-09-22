FROM ubuntu:24.04

WORKDIR /vsc

RUN apt-get update && apt-get install -y xxd && rm -rf /var/lib/apt/lists/*

COPY . .

RUN sed -i 's/\r$//' assembler.sh emulator.sh
RUN chmod +x assembler.sh emulator.sh

CMD ["/bin/bash"]