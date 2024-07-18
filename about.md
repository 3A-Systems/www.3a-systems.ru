---
layout: main
---

<section class="page-section">
    <div class="container px-4 px-lg-5 py-5">
        <div class="row justify-content-center">
            <div class="col text-center"><h2 class="text-center mt-0">О компании</h2></div>
        </div>
        <hr class="divider" />
        <div class="row gx-4 gx-lg-5 justify-content-center">
            {% for item in site.data.about %}
            <div class="col-lg-3 col-md-6 text-center">
                <div class="mt-5">
                    <div class="mb-2"><i class="{{item.icon}} fs-1 text-primary"></i></div>
                    <p class="text-muted mb-0">{{item.desc}}</p>
                </div>
            </div>           
            {% endfor %}
        </div>
    </div>
</section>