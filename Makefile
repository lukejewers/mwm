CC          = swiftc
TARGET      = mwm
SRC         = main.swift
PLIST       = com.user.mwm.plist
AGENT_DIR   = $(HOME)/Library/LaunchAgents
BINARY_DEST = /usr/local/bin/$(TARGET)

.PHONY: all install uninstall clean restart

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(SRC) -o $(TARGET)

install: $(TARGET)
	@echo "Stopping existing agent if running..."
	-launchctl unload $(AGENT_DIR)/$(PLIST) 2>/dev/null || true

	@echo "Installing binary..."
	sudo cp -f $(TARGET) $(BINARY_DEST)

	@echo "Loading agent..."
	launchctl load $(AGENT_DIR)/$(PLIST)
	@echo "Installation complete."

uninstall:
	-launchctl unload $(AGENT_DIR)/$(PLIST) 2>/dev/null || true
	sudo rm -f $(BINARY_DEST)
	@echo "Uninstalled."

clean:
	rm -f $(TARGET)

restart:
	launchctl unload $(AGENT_DIR)/$(PLIST)
	launchctl load $(AGENT_DIR)/$(PLIST)
