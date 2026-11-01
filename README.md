## Licensing

This project uses a dual licensing model::

* **Code and Theme:** The underlying Hugo theme, templates, layouts, HTML, CSS, JavaScript, and any other configuration files or scripts used to build and display the website are licensed under the **[MIT License](LICENSE)**. You are free to reuse, modify, and distribute this code as per the terms of the MIT License.

* **Content:** All textual content (blog posts, articles, pages), images, photographs, and other original media files created by Andrii Sudak and located primarily within the `/content/` and `/static/images/` (or similar user-generated content directories) are licensed under the **Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License (CC BY-NC-ND 4.0)**.
    * You are free to share (copy and redistribute the material in any medium or format) under the following terms:
        * **Attribution (BY):** You must give appropriate credit to Andrii Sudak, provide a link to the license, and indicate if changes were made. You may do so in any reasonable manner, but not in any way that suggests the licensor endorses you or your use.
        * **NonCommercial (NC):** You may not use the material for commercial purposes.
        * **NoDerivatives (ND):** If you remix, transform, or build upon the material, you may not distribute the modified material.
    * The full license text can be found here: [https://creativecommons.org/licenses/by-nc-nd/4.0/](https://creativecommons.org/licenses/by-nc-nd/4.0/)
* **Syndicated Content & Comments:** Posts dynamically syndicated at build time from [Mastodon](https://infosec.exchange/@andrii_sudak) (microblogging), [Pixelfed](https://fotolibre.social/andrii-sudak) (photography) and [DEV.to](https://dev.to/andrii-sudak) (long-form technical articles) via the Hugo Content Adapter in `/content/posts/_content.gotmpl`, as well as live user comments loaded from the Fediverse and DEV.to, remain subject to their respective authors' rights. Any third-party media, links, or trademarks referenced in syndicated posts or comments belong to their respective owners and are not stored in this repository.

## Syndicated Sources & Data Portability

The site acts as an aggregator: no third-party content is committed by bots. Each source can additionally be backed by an optional local archive, which is merged with (and takes priority over) the live API data:

| Source | Config (`params.toml`) | Optional archive |
| --- | --- | --- |
| Mastodon | `[mastodon]` | `data/mastodon/archive.json` (array of Mastodon status objects) |
| Pixelfed | `[pixelfed]` | `data/pixelfed/archive.json` (array of Pixelfed status objects) |
| DEV.to | `[devto]` | `data/devto/archive.json` (array of DEV.to article objects incl. `body_html`) |

If a service shuts down or you migrate accounts, export your posts into the matching `archive.json` and they keep rendering at the same URLs (`/posts/<source>-<id>/`). A DEV.to backup can be created without an API key:

```bash
mkdir -p data/devto
curl -s "https://dev.to/api/articles?username=andrii-sudak&per_page=1000" | jq -r '.[].id' \
  | xargs -I{} curl -s "https://dev.to/api/articles/{}" | jq -s '.' > data/devto/archive.json
```

Please ensure you respect these distinctions when interacting with this repository's contents.

## Local Development & Debugging

This project includes a Dockerized setup to easily run and debug the Hugo site locally, using the latest extended version of Hugo.

### Prerequisites
- Docker and Docker Compose installed on your machine.

### Instructions

1. **Build and start the container:**
   Run the following command in the root of the project. It will build the image (fetching the latest Hugo version) and start the dev server:
   ```bash
   docker compose up -d
   ```

2. **Access the site:**
   Open your browser and navigate to:
   **[http://localhost:1313](http://localhost:1313)**

3. **View live logs (Debugging):**
   To see the Hugo build logs in real-time (useful for debugging template errors):
   ```bash
   docker compose logs -f hugo
   ```

4. **Stop the server:**
   When you are done developing, you can stop the container with:
   ```bash
   docker compose down
   ```

Any changes you make to the source files (`/content`, `/layouts`, etc.) will automatically trigger a live-reload in the browser.
