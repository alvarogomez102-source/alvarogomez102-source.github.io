/**
 * Carga un componente HTML dentro de un elemento.
 *
 * @param {string} elementId
 * @param {string} componentPath
 */
async function loadComponent(elementId, componentPath) {

    const element = document.getElementById(elementId);

    if (!element) {
        console.error(
            `No se encontró el elemento #${elementId}`
        );

        return;
    }

    try {

        const response = await fetch(componentPath);

        if (!response.ok) {
            throw new Error(
                `HTTP ${response.status}: ${response.statusText}`
            );
        }

        const html = await response.text();

        element.innerHTML = html;

    } catch (error) {

        console.error(
            `No se pudo cargar ${componentPath}:`,
            error
        );

    }
}


/**
 * Inicialización
 */
document.addEventListener("DOMContentLoaded", async() => {

    await Promise.all([
        loadComponent(
            "header",
            "components/header.html"
        ),

        loadComponent(
            "footer",
            "components/footer.html"
        )
    ]);

});