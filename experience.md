---
layout: main
---

<section id="experience" class="page-section">
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
                            <th scope="col">Компания</th>
                            <th scope="col">Наименование</th>
                            <th scope="col">Категория</th>
                        </tr>
                    </thead>
                    <tbody>
                        {% for exp in site.data.experience %}
                        <tr>
                            <td scope="row"><img class="company-logo" src="{{exp.logo}}" alt="{{exp.name}}"/></td>
                            <td scope="row">{{exp.name}}</td>
                            <td scope="row">{{exp.category}}</td>
                        </tr>
                        {% endfor %}                        
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</section>