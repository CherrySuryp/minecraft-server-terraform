FROM itzg/minecraft-server:stable 
ENV \
    EULA="true" \
    TYPE="NEOFORGE" \
    VERSION="1.21.1" \
    NEOFORGE_VERSION="21.1.208" \
    MAX_MEMORY="8G"

RUN mkdir -p /mods
COPY mods/ /mods/
