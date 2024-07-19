---
layout: main
---

<section class="page-section">
    <div class="container px-4 px-lg-5 py-5">
        <div class="row justify-content-center">
            <div class="col">
                <h1>Опыт</h1>
                <hr class="divider" />
            </div>
        </div>
        <div class="row">
            <div class="col">
                <table class="table">
                    <thead>
                        <tr>
                            <th scope="col">Колонка 1</th>
                            <th scope="col">Колонка 2</th>
                            <th scope="col">Колонка 3</th>
                        </tr>
                    </thead>
                    <tbody>
                        {% for exp in site.data.experience %}
                        <tr>
                            <td scope="row">{{exp.val1}}</td>
                            <td scope="row">{{exp.val2}}</td>
                            <td scope="row">{{exp.val2}}</td>
                        </tr>
                        {% endfor %}                        
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</section>