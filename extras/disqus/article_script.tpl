
{% if standalone %}
<div id="disqus_thread"></div>
<script type="text/javascript">
  // Disqus per-article code.  Based on Diqus's Universal Embed Code
  var disqus_shortname = 'EXAMPLE';       // required: replace example
                                              // with your forum shortname

  var disqus_identifier="EXAMPLE_{{id}}"; // Ditto.

  // Embed discussion thread
  (function() {
  var dsq = document.createElement('script');
  dsq.type = 'text/javascript';
  dsq.async = true;
  dsq.src = '//' + disqus_shortname + '.disqus.com/embed.js';

  (document.getElementsByTagName('head')[0] || 
   document.getElementsByTagName('body')[0]).appendChild(dsq);
  })();
</script>
<noscript>Comments (via <a href="http://disqus.com/">Disqus</a>) need
  JavaScript.  Sorry.</noscript>
<a href="http://disqus.com" class="dsq-brlink">comments powered by <span class="logo-disqus">Disqus</span></a>
{% else %}
<a href="{{permalink}}#disqus_thread"
   data-disqus-identifier="EXAMPLE_{{id}}"> // Must equal disqus_identifier
0 Comments
</a>
{% endif %}
