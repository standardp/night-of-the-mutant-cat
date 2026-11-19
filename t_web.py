from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    b=p.chromium.launch(channel="chrome", headless=True)
    pg=b.new_page(viewport={"width":1000,"height":700})
    msgs=[]; pg.on("console", lambda m: msgs.append(m.type+":"+m.text[:80]))
    pg.goto("http://localhost:8778/index.html"); pg.wait_for_timeout(9000)
    print("canvas:", pg.locator("canvas").count())
    pg.screenshot(path="godot_web.png")
    print("console:", [m for m in msgs if m.startswith("error")][:3])
    b.close()
