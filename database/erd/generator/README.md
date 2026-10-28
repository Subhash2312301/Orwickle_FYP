# ERD generator

Regenerates the Orwickle ERD from the live database.

```
npm install                                   # elkjs, playwright-core (uses Microsoft Edge)
cd ../../../backend && node --env-file=.env ../database/erd/generator/dump_schema.js ../database/erd/generator/schema.json
cd ../database/erd/generator && node to_data.mjs && node erd2.mjs .. 2
```
Groups, colours and the partial-unique rules are set in `to_data.mjs`.
