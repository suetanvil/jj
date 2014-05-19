<br><br>
{% for item in articles %}
{{item.pub_date}} <a href="{{item.page_url}}">{{item.subject}}</a><br>
{% endfor %}
