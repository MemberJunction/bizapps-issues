---
"@mj-biz-apps/issues-entities": patch
---

`mj sync push --dir metadata` now succeeds on a fresh database.

- `metadata/.mj-sync.json` lists every metadata folder in `directoryOrder`, ending with `record-processes`, `ml-training-pipelines`, `ml-models` and `ml-model-scoring-bindings`. Folders left out of the list are pushed afterwards in alphabetical order, so `ml-model-scoring-bindings` was pushed before the model and record process it references and the push rolled back on `FK_MLModelScoringBinding_MLModel`.
- The shipped ML model no longer carries `ArtifactFileID`. It pointed at a `__mj.File` row nothing ships, so the push failed on `FK_MLModel_ArtifactFile`. The trained artifact's bytes live on the machine that trained it (MemberJunction/MJ#4991), so the model scores only after it is trained on the host; until then each scheduled scoring run fails with `has no ArtifactFileID` (MemberJunction/MJ#4829).
