from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    b=p.chromium.launch(channel="chrome", headless=True)
    pg=b.new_page(viewport={"width":1000,"height":700})
    errs=[]; pg.on("console", lambda m: errs.append(m.text[:90]) if m.type=="error" else None)
    pg.goto("https://standardp.github.io/night-of-the-mutant-cat/play/"); pg.wait_for_timeout(12000)
    pg.screenshot(path="live_play.png")
    print("canvas:", pg.locator("canvas").count(), "errs:", errs[:2])
    b.close()
