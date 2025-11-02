.PHONY: bump-version release bump-and-release
bump-version:
	@echo "Bumping version to $(VERSION)"
	@sed -i 's/VICINAEXT_VERSION=".*"/VICINAEXT_VERSION="$(VERSION)"/' vicinaext.sh
	@sed -i 's|/releases/download/v[^/]*/vicinaext.sh|/releases/download/v$(VERSION)/vicinaext.sh|g' README.md
	@git add vicinaext.sh README.md
	@git commit -m "Bump version to $(VERSION)"
	@git push
	@echo "vicinaext version bumped to $(VERSION)"

release:
	@echo "Releasing version $(VERSION)"
	@git tag v$(VERSION)
	@git push origin v$(VERSION)
	@echo "vicinaext version v$(VERSION) released"

bump-and-release: bump-version release
