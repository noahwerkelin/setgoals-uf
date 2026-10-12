# Architecture rules
- Keep personal earning-rule and cap edits PRO-gated in both settings interfaces and in a database validation trigger, so old clients cannot bypass subscription access; do not gate parent-managed child rules or daily step goals.
- Keep the Swift and web upgrade views aligned using the existing semantic themes and bilingual translation dictionaries; preserve the existing purchase, restore, and child inheritance flows.
- The iOS AI coach goes through one authenticated server route that reads data via RLS as the caller; the model may only propose actions (goal, challenge, navigation) that the app applies after user confirmation, so AI output can never change settings or grant screen time.
