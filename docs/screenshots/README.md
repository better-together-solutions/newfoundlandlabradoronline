# Screenshots

Desktop (1440x1600) and mobile (430x1400) captures, plain and `_annotated` (numbered outlines on callout targets),
written by `spec/support/docs_screenshots.rb` from specs in `spec/docs_screenshots/`.

```bash
./bin/dc-run env RUN_DOCS_SCREENSHOTS=1 bundle exec rspec spec/docs_screenshots/<feature>_spec.rb
```

Start from `spec/docs_screenshots/template.rb.example`. Open every PNG and confirm the target is in frame and not covered by its callout.
