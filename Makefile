.PHONY: install test clean help

PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

SCRIPT_NAME = vicinaext.sh
SCRIPT_PATH = $(SCRIPT_NAME)

help:
	@echo "Available targets:"
	@echo "  install  - Install vicinaext.sh to $(BINDIR)"
	@echo "  test     - Run basic tests"
	@echo "  clean    - Remove installed files"
	@echo "  help     - Show this help message"

install:
	@echo "Installing $(SCRIPT_NAME) to $(BINDIR)..."
	install -m 755 $(SCRIPT_PATH) $(BINDIR)/vicinaext
	@echo "Installation complete. Make sure $(BINDIR) is in your PATH."

test:
	@echo "Running basic tests..."
	@./$(SCRIPT_NAME) --version
	@./$(SCRIPT_NAME) --help > /dev/null
	@echo "Tests passed!"

clean:
	@echo "Removing $(SCRIPT_NAME) from $(BINDIR)..."
	rm -f $(BINDIR)/vicinaext
	@echo "Cleanup complete."
