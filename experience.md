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
                            <th scope="col">Деятельность</th>
                        </tr>
                    </thead>
                    <tbody>
                        {% for exp in site.data.experience %}
                        <tr>
                            <td scope="row" class="logo">
                                <a href="{{exp.link}}" target="_blank">
                                    <img class="company-logo {{exp.class}}" src="{{exp.logo}}" alt="{{exp.name}}"/>
                                </a>
                            </td>
                            <td scope="row"><a href="{{exp.link}}" target="_blank">{{exp.name}}</a></td>
                            <td scope="row">{{exp.category}}</td>
                        </tr>
                        {% endfor %}                        
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</section>