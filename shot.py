from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    b=p.chromium.launch(channel="chrome", headless=True)
    pg=b.new_page(viewport={"width":1100,"height":880})
    pg.goto("http://localhost:8777/index.html"); pg.wait_for_timeout(1200)
    pg.click('[data-hs="beast"]'); pg.wait_for_timeout(400)
    pg.screenshot(path="shot_living.png")
    b.close()
