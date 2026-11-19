from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    b=p.chromium.launch(channel="chrome", headless=True)
    pg=b.new_page(viewport={"width":1100,"height":900})
    errs=[]; pg.on("pageerror", lambda e: errs.append(str(e)))
    pg.goto("http://localhost:8777/index.html"); pg.wait_for_timeout(500)
    pg.click('[data-lang="en"]'); pg.wait_for_timeout(300)
    pg.click('[data-v="LOOK"]'); pg.click('[data-hs="beast"]'); pg.wait_for_timeout(300)
    print("VERBS EN:", pg.inner_text("#verbs").replace("\n","|"))
    print("LOOK:", pg.inner_text("#log")[:120])
    print("ERR:", errs[:2])
    b.close()
