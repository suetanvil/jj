<html>
<head>
<title>{{title}}</title>
<meta http-equiv="content-type" content="text/html; charset=utf8" />
{{hdr_script}}
</head>
<LINK rel="stylesheet" HREF="{{rootpath}}/white.css">

<body>

<div id="header">
	  <h1>{{richtitle}}</h1>
	  <i><br><center>By {{author}}</center><br></i>
	  <i><br><center>{{subtitle}}</center><br></i>

	  <div id="links">
		<ul>
            {% for link in links %}
                <li><a href="{{link[1]}}">{{link[0]}}</a></li>
            {% endfor %}
		</ul>
	  </div>
	  <br>
	
	  </ul>
</div>
<br>
<br>

{% if standalone %}
{% else %}
<div id="sidebar">
	  <h1>Recent Articles:</h1>
	  <div class="contents">
        {{recent_links}}
	  </div>
	  <br>
	  <br>
	  <div class="contents">
		<a href="{{archive_link}}">Archives</a>
	  </div>
</div>
{% endif %}

<div id="content">
  {{content}}
</div>

<div id="mainfooter">
	  <hr>
	  {{copyright}} <br>
	  {{disclaimer}}
</div>

{{body_script}}
</body>	
</html>














