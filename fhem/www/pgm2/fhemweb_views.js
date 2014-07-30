function saveOrder() {
    var SaveResult = "";
	//------------- Build new Position string ---------------
    $(".ui-column").each(function(index, value){        
		var colid = value.id;
        var order = $('#' + colid).sortable("toArray");
        for ( var i = 0, n = order.length; i < n; i++ ) {
            var v = $('#' + order[i]).find('.ui-widget-content').is(':visible');
			var w = $('#' + order[i]).outerWidth();
			if ( $('#' + order[i]).find(".ui-widget-content").data("userheight") == null ) { 
				var h = $('#' + order[i]).outerHeight(); 
			} else {
				var h = $('#' + order[i]).find(".ui-widget-content").data("userheight"); 
				if (h.length == 0) { var h = $('#' + order[i]).outerHeight(); }
			}
            order[i] = order[i]+","+v+","+h+","+w;	
        }
		SaveResult = SaveResult + index+','+order+':';
		//Result: <ColumNumber>,<portlet-1>,<status>,<height>,<width>,<portlet-n>,<status>,<height>,<width>:<columNumber.....		
    });	
	//-------------------------------------------------------	
	//------------ Set the new href String ------------------
	document.getElementById("views_currentsorting").value = SaveResult;	
	if (document.getElementById("view-button-set")) {
		document.getElementById("view-button-set").classList.add('viewoptionbutton-changed'); //Mark that the Changes are not saved
	}
	//-------------------------------------------------------
}

function restoreOrder() {
  $(".ui-column").each(function(index, value) {
	var params = (document.getElementById("views_attr").value).split(","); //get current Configuration
	var coldata = (document.getElementById("views_currentsorting").value).split(":");	//get the position string from the hiddenfield 
	//------------------------------------------------------------
	$(".ui-column").width(params[1]); //Set Columwidth
	if (params[2] == 1) { $(".ui-column").addClass("ui-column-showhelper"); } else { $(".ui-column").removeClass("ui-column-showhelper"); }//set helperclass

	for (var i = 0, n = coldata.length; i < n; i++ ) { //for each column (Value = 1,name1,state1,name2,state2)
		var portletsdata = coldata[i].split(","); //protlet array / all portlets in this (=index) column
		
		//alert("Load Event (1) \nColumn="+index+"\nSaveResult="+coldata+"\nColumndata=("+i+"/"+coldata.length+") "+portletsdata);
		for (var j = 1, m = portletsdata.length; j < m; j += 4 ) { 
			//alert("Load Event (2) \nColumn="+index+"\nSaveResult="+coldata+"\nColumndata=("+i+"/"+coldata.length+"|"+j+"/"+portletsdata.length+") "+portletsdata+
			//"\n\nPortletdata (ID)="+portletsdata[j]+"\nPortletdata (Visible)="+portletsdata[j+1]+"\nPortletheight (Height)="+portletsdata[j+2]+"\nPortletwidth (Width)="+portletsdata[j+3]);	
			if (portletsdata[0] == index && portletsdata[0] != '' && portletsdata[j] != '' && portletsdata[j+1] != '') {
				var portletID = portletsdata[j];
				var visible   = portletsdata[j+1];
				var height    = portletsdata[j+2];
				var width     = portletsdata[j+3]; //change this in future release if width dynamic!
				if (width > params[1]) {width = params[1]}; //Fix with ist widget width > current column width.
				
				var portlet = $(".ui-column").find('#' + portletID);
				portlet.appendTo($('#' + value.id));				
				portlet.outerHeight(height);					
				portlet.outerWidth(width);					
				if (params[2] == 1) { portlet.addClass("ui-widget-showhelper"); } else { portlet.removeClass("ui-widget-showhelper"); }//Show Widget-Helper Frame
				if (visible === 'false') {			
					if (portlet.find(".ui-widget-header").find(".ui-icon").hasClass("ui-icon-minus")) { 
						portlet.find(".ui-widget-header").find(".ui-icon").removeClass( "ui-icon-minus" ); 
						portlet.find(".ui-widget-header").find(".ui-icon").addClass( "ui-icon-plus" ); 
					}
					var currHeigth = Math.round(portlet.height());
					portlet.find(".ui-widget-content").data("userheight", currHeigth);
					portlet.find(".ui-widget-content").hide();	
					var newHeigth = portlet.find(".ui-widget-inner").height()+5;		
					portlet.height(newHeigth);								
				}
			}
		}	
	} 
  });	
} 

function FWView_tooglelock(){
 var params = (document.getElementById("views_attr").value).split(","); //get current Configuration
 if (params[3] == "lock"){ //current state lock, do unlock
	params[3] = "unlock"; 	
	$(".viewoptionbutton-lock").button( "option", "label", "Lock" );
	FWView_setunlock();
 } else { //current state unlock, set lock
	params[3] = "lock"; 
	$(".viewoptionbutton-lock").button( "option", "label", "Unlock" );
	FWView_setlock();
 } 
 document.getElementById("views_attr").value = params; 
 FW_cmd(document.location.pathname+'?XHR=1&cmd.'+params[0]+'=attr '+params[0]+' view_lockstate '+params[3]);
}

function FWView_setlock(){
	$(".viewoptionbutton-lock")		
		.removeClass("ui-icon-lock")
		.addClass("ui-icon-unlock");
	//############################################################
	$( ".ui-column" ).sortable( "option", "disabled", true );
	$( ".ui-widget" ).removeClass("ui-widget-showhelper");
	if ($( ".viewwidget" ).hasClass("ui-resizable")) { $( ".viewwidget" ).resizable("destroy"); };
	$( ".ui-column" ).removeClass("ui-column-showhelper");
	//############################################################
}

function FWView_setunlock(){
	var params = (document.getElementById("views_attr").value).split(","); //get current Configuration
	$(".viewoptionbutton-lock")
		.removeClass("ui-icon-unlock")
		.addClass("ui-icon-lock");	
	//############################################################
	$( ".ui-column" ).sortable( "option", "disabled", false );
	if (params[2] == 1) { $( ".ui-widget" ).addClass("ui-widget-showhelper"); } else { $( ".ui-widget" ).removeClass("ui-widget-showhelper"); }//Show Widget-Helper Frame
	if (params[2] == 1) { $( ".ui-column" ).addClass("ui-column-showhelper"); } else { $( ".ui-column" ).removeClass("ui-column-showhelper"); }//Show Widget-Helper Frame
	$( ".viewwidget" ).resizable();
	//############################################################
}

function FWView_setposition(){
	var params = (document.getElementById("views_attr").value).split(","); //get current Configuration
	var sorting = document.getElementById("views_currentsorting").value;
	FW_cmd(document.location.pathname+'?XHR=1&cmd.'+params[0]+'=attr '+params[0]+' view_sorting '+sorting);
	document.getElementById("view-button-set").classList.remove('viewoptionbutton-changed'); 
}

function FWView_modifyWidget(){

	if ($(".viewwidget").data("status") != "initialized") {
		$(".viewwidget")
			.addClass( "viewwidget ui-widget-content ui-corner-all" )
			.find(".ui-widget-header")
			.addClass( "ui-widget-header ui-corner-all" )
			.prepend('<span class="ui-icon ui-icon-minus"></span>')
			.end();
		
		$( ".viewwidget" ).resizable({ 
			'grid': 1,
			'minWidth':  150,
			start: function(e, ui) {
				var params = (document.getElementById("views_attr").value).split(","); //get current Configuration
				maxWidthOffset = params[1];				
			},
			resize: function(e, ui) {
				minHeightOffset = $(this).find(".ui-widget-inner").height()+5;
				ui.size.width = Math.round(ui.size.width);
				if (ui.size.width > (maxWidthOffset)) {	$(this).resizable("option","maxWidth",maxWidthOffset); }
				if (ui.size.height < (minHeightOffset)) { $(this).resizable("option","minHeight",minHeightOffset); }	
			},
			stop: function() { 
				minHeightOffset = $(this).find(".ui-widget-inner").height()+5;
				$(this).resizable("option","minHeight",minHeightOffset);
				saveOrder(); 
			} 
		});		
		$(".viewwidget").data("status", "initialized");	
	}	
}

$(document).ready( function () {
	var params = (document.getElementById("views_attr").value).split(","); //get current Configuration
	
    $(".ui-column").sortable({
        connectWith: ['.ui-column'],
        stop: function() { saveOrder(); }
    }); 
	
	if (params[4] == 0){ //set if buttonbar not show
		FWView_modifyWidget();
		FWView_setlock();		
	} 
// Comming soon ......
//	$( ".ui-column" ).resizable({	
//		handles: 'e',
//		alsoResize: "#sortablecolumn0,#sortablecolumn1,#sortablecolumn2,#sortablecolumn3,#sortablecolumn4"
//	});
//    $(".ui-row").sortable({
//        connectWith: ['.ui-row']
//    }); 	
// eine Zeile ohne spalte on top an bottom per option für seitenbreites widget


    restoreOrder(); 

    $(".ui-widget-header .ui-icon").click(function(event) { //andere classe vorhanden/verwenden?
		if ($(this).hasClass("ui-icon-plus")) {
			$(this).removeClass( "ui-icon-plus" );
			$(this).addClass( "ui-icon-minus" );
			$(this).parents(".ui-widget:first").find(".ui-widget-content").show();				
			var newHeigth = $(this).parents(".ui-widget:first").find(".ui-widget-content").data("userheight");	
		} else {
			$(this).removeClass( "ui-icon-minus" );
			$(this).addClass( "ui-icon-plus" );			
			var currHeigth = Math.round($(this).parents(".ui-widget:first").height());
			$(this).parents(".ui-widget:first").find(".ui-widget-content").data("userheight", currHeigth);
			$(this).parents(".ui-widget:first").find(".ui-widget-content").hide();	
			var newHeigth = $(this).parents(".ui-widget:first").find(".ui-widget-inner").height()+5;			
		}				 
		$(this).parents(".ui-widget:first").height(newHeigth);
		saveOrder();
		event.stopImmediatePropagation();
    });

	$(".viewoptionbutton-set").button({
		create: function( event, ui ) {
			$(this).addClass("ui-icon-set");
		}
	});
	
	$(".viewoptionbutton-lock").button({
		create: function( event, ui ) {
			FWView_modifyWidget();
			if (params[3] == "lock") { 
				$(this).button( "option", "label", "Unlock" );
				FWView_setlock(); 
			} else {
				$(this).button( "option", "label", "Lock" );
				FWView_setunlock();				
			}
		}
	});
//alert("JS Ende");	
});




