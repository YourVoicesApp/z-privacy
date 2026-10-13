"""Name the Dart tests that failed, out of `flutter test`'s own JSON record.

The compact reporter rewrites one line, so a log of it keeps only the last
state: seven failures came back as one name and a RenderFlex dump from an
unrelated file. The JSON record keeps every event, and this prints the one
thing a person needs first — which tests failed, and in which file.
"""
import json
import sys

names = {}
failed = []
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    line = line.strip()
    if not line.startswith("{"):
        continue
    try:
        event = json.loads(line)
    except ValueError:
        continue
    if event.get("type") == "testStart":
        test = event["test"]
        # `root_url` is the test file; `url` is where the closure was built,
        # which for every `testWidgets` is the framework's own widget_tester.
        names[test["id"]] = (test["name"], test.get("root_url") or test.get("url") or "")
    elif event.get("type") == "testDone" and event.get("result") != "success" and not event.get("hidden"):
        failed.append(names.get(event["testID"], ("?", "")))
for name, url in failed:
    where = url.rsplit("/", 1)[-1] if url else "?"
    print(f"{where}: {name}")
if not failed:
    print("no test reported a failure — the suite itself did not finish")
