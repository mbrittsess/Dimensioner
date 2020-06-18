--TOOL INFORMATION
TOOL.Category		= "Render"
TOOL.Name			= "#Dimensioner"
TOOL.Command		= nil
TOOL.ConfigName		= ""

--TOOL NAME, DESCRIPTION, INSTRUCTIONS
if CLIENT then
language.Add( "Tool_dimensioner_name", "Dimensioner Tool" )
language.Add( "Tool_dimensioner_desc", "Allows you to measure parts of a model." )
language.Add( "Tool_dimensioner_0", "Primary: Set   Secondary: Reset" )
end

--CONVENIENCE/SPEED LOCALS
local format = string.format

if SERVER then

function TOOL:LeftClick( trace )
    umsg.Start("LeftClicked", self:GetOwner()) umsg.End()
    return trace.Hit and (not trace.HitWorld)
end

function TOOL:RightClick( trace )
    umsg.Start("RightClicked", self:GetOwner()) umsg.End()
    return false
end

end

if CLIENT then

local PrussianBlue = Color(102,102,204,255)
local White = Color(255,255,255,255)

local CurrentlySetEntity = nil
local CamViewOffset = Vector(0,0,0)
local GridOffset = Vector(0,0,0)
local GridSpacing = Vector(0,0,0)

local GridIsUnderlay = false --TODO: Once GMod goes to version 13, this can be set by a DComboBox

local PanelReference = {}
    --[[Contains the following panels:
        BGColor - Background Color Selector
        LinesColor - Lines Color Selector]]

usermessage.Hook("LeftClicked", function()
    local trace = LocalPlayer():GetEyeTraceNoCursor()
    
    if trace.Hit and (not trace.HitWorld) then
        CurrentlySetEntity = trace.Entity
        PanelReference.ExtentWang:SetValue(CurrentlySetEntity:BoundingRadius())
    end
end)

usermessage.Hook("RightClicked", function()
    CurrentlySetEntity = nil
end)

local ViewArgsIndex
local function SetCameraToStandardView(view) --Ended up changing how this works, ended up being more complex than necessary.
    ViewArgsIndex = view
end
local GetCameraViews
do local positions = { --:GetXXX to call, scalar to multiply result by
    Front  = {"Forward",  1};
    Right  = {"Right",    1};
    Back   = {"Forward", -1};
    Left   = {"Right",   -1};
    Top    = {"Up",       1};
    Bottom = {"Up",      -1};
   }
   local angletransforms = { --Call :GetAngles(), rotate result around :GetXXX by YYY degrees for each
    Front  = {{"Up",      180}};
    Right  = {{"Up",       90}};
    Back   = {{"Up",        0}};
    Left   = {{"Up",      270}};
    Top    = {{"Up",       90};
              {"Forward", 270}};
    Bottom = {{"Up",       90};
              {"Forward",  90}};
   }
   
   GetCameraViews = function(Ent) --Pass this an ent, get back a normalized relative camera position, and camera angles
    local RetNormPos = Ent["Get"..positions[ViewArgsIndex][1]](Ent) * positions[ViewArgsIndex][2]
    
    local RetAng = Ent:GetAngles()
    for _,operations in ipairs(angletransforms[ViewArgsIndex]) do
        RetAng:RotateAroundAxis(Ent["Get"..operations[1]](Ent), operations[2])
    end
    
    return RetNormPos, RetAng
   end
end

local function DrawPanelGrid(self)
    local panw, panh = self:GetWide(), self:GetTall()
    local extent = PanelReference.ExtentWang:GetValue()
    local CamOfs = {x = PanelReference.XWangCam:GetValue(), y = -PanelReference.YWangCam:GetValue()}
    local GridOfs = {x = PanelReference.XWangGridOfs:GetValue(), y = -PanelReference.YWangGridOfs:GetValue()}
    local Spacing = {x = PanelReference.XWangGridSpace:GetValue(), y = PanelReference.YWangGridSpace:GetValue()}
    
    local LinesCol = PanelReference.LinesColor:GetColor()
    
    local UnitDim = {}
      if panw < panh then
        UnitDim.x, UnitDim.y = extent, extent * (panh/panw)
      else
        UnitDim.x, UnitDim.y = extent * (panw/panh), extent
      end
    
    local PxDim = {x = panw, y = panh}
    
    surface.SetDrawColor(LinesCol)
    surface.SetTextColor(LinesCol)
    surface.SetFont("Default")
    
    do local RoundToPosInf, RoundToNegInf, insert, DrawLine, fmt = math.ceil, math.floor, table.insert, surface.DrawLine, string.format
    for _,Axis in ipairs{"x","y"} do
        local OppAxis = (Axis == "x") and "y" or "x"
        local OppDim = PxDim[OppAxis]
        
        local UnitDim, PxDim, CamOfs, GridOfs, Spacing = UnitDim[Axis], PxDim[Axis], CamOfs[Axis], GridOfs[Axis], Spacing[Axis]
        local UnitBack = -((UnitDim / 2) - CamOfs)
        local UnitForward = UnitBack + UnitDim
        
        local LoopStart = RoundToPosInf((UnitBack - GridOfs) / Spacing)
        local LoopEnd = RoundToNegInf((UnitForward - GridOfs) / Spacing)
        
        local DoStart = true and (((LoopStart * Spacing) + GridOfs) > UnitBack)    or false
        local DoEnd   = true and (((LoopEnd   * Spacing) + GridOfs) < UnitForward) or false
        
        local LinesToDraw = {}
        
        do local function AddToLinesToDraw(val)
            local entry = {
                ((((val * Spacing) + GridOfs) - UnitBack) * (PxDim / UnitDim)),
                ((val * Spacing) + GridOfs)}
            if Axis == "y" then entry[2] = entry[2] * -1 end
                insert(LinesToDraw, entry)
        end
        if DoStart and DoEnd then
            for i = LoopStart, LoopEnd do
                AddToLinesToDraw(i)
            end
        elseif DoStart then
            AddToLinesToDraw(LoopStart)
        elseif DoEnd then
            AddToLinesToDraw(LoopEnd)
        end end
        
        for _,AxisDim in ipairs(LinesToDraw) do
            local StartCoord, EndCoord = {[Axis] = AxisDim[1], [OppAxis] = 0}, {[Axis] = AxisDim[1], [OppAxis] = OppDim}
            
            local label = fmt("%d", AxisDim[2])
            TextSizeW, TextSizeH = surface.GetTextSize(label)
            
            --In general, we are offsetting the text from both the edge, and its starting line, by half of its height.
            local TextAlignmentBack, TextAlignmentForward, LineAlignment
            if Axis == "y" then
                TextAlignmentBack    = {x = TextSizeH / 2, y = -(TextSizeH / 2)}
                TextAlignmentForward = {x = -((TextSizeH / 2) + TextSizeW), y = -(TextSizeH / 2)}
                LineAlignment        = {x = TextSizeH * 2, y = 0}
            else--if Axis == "x" then
                TextAlignmentBack    = {x = -(TextSizeW / 2), y = TextSizeH / 2}
                TextAlignmentForward = {x = -(TextSizeW / 2), y = -(TextSizeH * 1.5)}
                LineAlignment        = {x = 0, y = TextSizeH + TextSizeW}
            end
            
            surface.SetTextPos(StartCoord.x + TextAlignmentBack.x, StartCoord.y + TextAlignmentBack.y)
            surface.DrawText(label)
            surface.SetTextPos(EndCoord.x + TextAlignmentForward.x, EndCoord.y + TextAlignmentForward.y)
            surface.DrawText(label)
            
            DrawLine(StartCoord.x + LineAlignment.x, StartCoord.y + LineAlignment.y,
                        EndCoord.x - LineAlignment.x, EndCoord.y - LineAlignment.y)
        end
    end end
end

local function DrawPanelModel( self )
    local panw, panh = self:GetWide(), self:GetTall()
    local absx, absy = self:LocalToScreen()
    local Ent = CurrentlySetEntity
    
    --Draw background
    do local BGColor = PanelReference.BGColor:GetColor()
        BGColor.a = 255
        surface.SetDrawColor(BGColor)
    end
    surface.DrawRect(0, 0, panw, panh)
    
    if (not Ent) or (not Ent:IsValid()) then return end
    
    if GridIsUnderlay then DrawPanelGrid(self) end
    
    local RenderExtent = PanelReference.ExtentWang:GetValue()
  --local RenderExtent --Calculate the farthest along an axis any RenderBounds vector gets
    --[[
    do  local oldAng = Ent:GetAngles()
        Ent:SetAngles(Angle(0,0,0))
        local Bounds1, Bounds2 = Ent:GetRenderBounds()
        local Candidates = {Bounds1.x, Bounds1.y, Bounds1.z, Bounds2.x, Bounds2.y, Bounds2.z}
        table.sort(Candidates)
        RenderExtent = Candidates[#Candidates]
        Ent:SetAngles(oldAng)
    end
    --]]
    
    local WorldBounds
    if panw > panh then
        WorldBounds = {W = RenderExtent * (panw / panh),
                       H = RenderExtent}
    else
        WorldBounds = {W = RenderExtent,
                       H = RenderExtent * (panh / panw)}
    end
    
    local campos, camang = GetCameraViews(Ent)
    campos = (campos * RenderExtent) + (camang:Right() * CamViewOffset.x) + (camang:Up() * CamViewOffset.y)
    cam.Start3D(Ent:GetPos() + campos, camang)
      render.SetViewPort(absx, absy, self:GetWide(), self:GetTall())
      cam.StartOrthoView(-WorldBounds.W/2, WorldBounds.H/2, WorldBounds.W/2, -WorldBounds.H/2)
        Ent:DrawModel()
      cam.EndOrthoView()
    cam.End3D()
    
    if not GridIsUnderlay then DrawPanelGrid(self) end
end

local LargeDrawFrame = vgui.Create("DFrame")
    LargeDrawFrame:SetParent(vgui.GetWorldPanel())
    LargeDrawFrame:SetTitle("Dimensioner Full-Size Display")
    LargeDrawFrame:SetPos(0,0)
    LargeDrawFrame:StretchToParent(0,0,0,0)
    LargeDrawFrame:SetDraggable(false)
    LargeDrawFrame:ShowCloseButton(true)
    LargeDrawFrame:SetDeleteOnClose(false)
    LargeDrawFrame:SetVisible(false)
    local LargeDrawPanel = vgui.Create("DPanel")
        LargeDrawPanel:SetParent(LargeDrawFrame)
        LargeDrawPanel:StretchToParent(3, 22+3, 3, 3)
        LargeDrawPanel.Paint = DrawPanelModel

function TOOL.BuildCPanel( CPanel ) --This apparently needs to not be a method. Not that it's documented anywhere.
    local SmallDrawLabel = vgui.Create("DLabel")
        SmallDrawLabel:SetText("Preview:")
    local PopOutButton = vgui.Create("DButton")
        PopOutButton:SetText("Full View")
        PopOutButton:SetToolTip("Click for full-size view.")
        PopOutButton.DoClick = function(self) LargeDrawFrame:SetVisible(true) LargeDrawFrame:MakePopup() print("Received DoClick") end
    CPanel:AddItem(SmallDrawLabel, PopOutButton)
    
    local SmallDrawPanel = vgui.Create("DPanel")
        SmallDrawPanel.PerformLayout = function(self)
            local size = CPanel:GetWide() - (CPanel:GetPadding() * 2)
            self:SetSize(size, size)
        end
        SmallDrawPanel.Paint = function(self) if not LargeDrawFrame:IsVisible() then DrawPanelModel(self) end end
   --[=[SmallDrawPanel:SetToolTip("Double-click for full-size view.")
        do local LastClickWasDoubleClick, LastClickTime, SysTime = false, SysTime(), SysTime
        SmallDrawPanel.DoClick = function() --Not using its parameters.
            local ThisTime = SysTime()
            if (not LastClickWasDouble) and ((ThisTime - LastClickTime) < 0.3) then --[[0.3 is the same number Garry uses for his own
                double-clickc, so this wasn't pulled *completely* out of our asses.]]
                --This counts as a double-click, so show our pop-out panel.
                LargeDrawFrame:SetVisible(true)
                LastClickWasDouble = true
            else
                LastClickWasDouble = false
            end
            LastClickTime = ThisTime
        end end --]=]
        CPanel:AddItem(SmallDrawPanel)

    local ViewControlsLabel = vgui.Create("DLabel")
        ViewControlsLabel:SetText("View Controls:")
        ViewControlsLabel:SizeToContents()
        CPanel:AddItem(ViewControlsLabel)
    
    local StandardViewsLabel = vgui.Create("DLabel")
        StandardViewsLabel:SetText("Standard Views")
        StandardViewsLabel:SizeToContents()
        CPanel:AddItem(StandardViewsLabel)
    
    local StandardViewsContainer = vgui.Create("DPanel")
        do local Padding, Spacing = CPanel:GetPadding(), CPanel:GetSpacing()
            local Buttons = {
                {"Top",    "Front", "Left" };
                {"Bottom", "Back",  "Right"};
            }
            
            for RowNumber, Columns in ipairs(Buttons) do
                for ColumnNumber, ButtonName in ipairs(Columns) do
                    local Button = vgui.Create("DButton", StandardViewsContainer)
                    Button:SetText(ButtonName)
                    Button:SetToolTip(format("Moves camera to a %s view of the model.", ButtonName:lower()))
                    Button.DoClick = function(self) SetCameraToStandardView(ButtonName) end
                    Buttons[RowNumber][ColumnNumber] = Button
                end
            end
        StandardViewsContainer.PerformLayout = function(self)
            local ButtonWidth = ((CPanel:GetWide() - (CPanel:GetPadding() * 4)) / 3)
            local ButtonSpacing = ButtonWidth + CPanel:GetPadding()
            local y = Buttons[1][1]:GetTall() + CPanel:GetSpacing()
            for RowNumber, Columns in ipairs(Buttons) do
                for ColumnNumber, Button in ipairs(Columns) do
                    Button:SetPos((ColumnNumber - 1) * ButtonSpacing, (RowNumber - 1) * y)
                    Button:SetWide(ButtonWidth)
                end
            end
            self:SetTall((Buttons[1][1]:GetTall() * 2) + CPanel:GetSpacing())
        end
        end
        CPanel:AddItem(StandardViewsContainer)
        SetCameraToStandardView("Front")
    
    local ViewOffsetLabel = vgui.Create("DLabel")
        ViewOffsetLabel:SetText("View Offset (Right, Up)")
        CPanel:AddItem(ViewOffsetLabel)
    
    local XWangCam = vgui.Create("DNumberWang")
        XWangCam:SetToolTip("Positive values here will move the camera towards screen-right.")
        XWangCam.OnValueChanged = function(self, NewValue) CamViewOffset.x = NewValue end
        XWangCam:SetDecimals(0)
        XWangCam:SetMinMax(-32768, 32767) --These values are completely arbitrary.
        XWangCam:SetValue(0)
        PanelReference.XWangCam = XWangCam
    local YWangCam = vgui.Create("DNumberWang")
        YWangCam:SetToolTip("Positive values here will move the camera towards screen-up.")
        YWangCam.OnValueChanged = function(self, NewValue) CamViewOffset.y = NewValue end
        YWangCam:SetDecimals(0)
        YWangCam:SetMinMax(-32768, 32767)
        YWangCam:SetValue(0)
        PanelReference.YWangCam = YWangCam
        CPanel:AddItem(XWangCam,YWangCam)
    
    local SetViewCenterButton = vgui.Create("DButton")
        SetViewCenterButton:SetText("Center View")
        SetViewCenterButton:SetToolTip("Resets view offset to center.")
        SetViewCenterButton.DoClick = function(self) CamViewOffset.x, CamViewOffset.y = 0, 0 end
        CPanel:AddItem(SetViewCenterButton)
    
    local ExtentWangLabel = vgui.Create("DLabel")
        ExtentWangLabel:SetText("Exent (span)")
        CPanel:AddItem(ExtentWangLabel)
    
    local ExtentWang = vgui.Create("DNumberWang")
        ExtentWang:SetToolTip("Controls how many world-units the smaller of the display panel's dimensions spans.")
        ExtentWang:SetDecimals(1)
        ExtentWang:SetMinMax(0, 32767)
        ExtentWang:SetValue(256)
        PanelReference.ExtentWang = ExtentWang
        CPanel:AddItem(ExtentWang)
    
    local GridControlsLabel = vgui.Create("DLabel")
        GridControlsLabel:SetText("Grid Controls:")
        CPanel:AddItem(GridControlsLabel)
    
    local GridColorsLabel = vgui.Create("DLabel")
        GridColorsLabel:SetText("Grid Colors (Background, Lines)")
        CPanel:AddItem(GridColorsLabel)
        
    local BackgroundColorSelector = vgui.Create("DColorMixer")
        BackgroundColorSelector:SetToolTip("Select the background color here.")
        BackgroundColorSelector:SetColor(PrussianBlue)
        BackgroundColorSelector:SetSize(140,100)
        PanelReference.BGColor = BackgroundColorSelector
    local LinesColorSelector = vgui.Create("DColorMixer")
        LinesColorSelector:SetToolTip("Select the lines color here.")
        LinesColorSelector:SetColor(White)
        LinesColorSelector:SetSize(140,100)
        PanelReference.LinesColor = LinesColorSelector
        CPanel:AddItem(BackgroundColorSelector, LinesColorSelector)
        LinesColorSelector:SetColor(White)
    
    local GridOffsetLabel = vgui.Create("DLabel")
        GridOffsetLabel:SetText("Grid Offset (Right, Up)")
        CPanel:AddItem(GridOffsetLabel)
    
    local XWangGridOfs = vgui.Create("DNumberWang")
        XWangGridOfs:SetToolTip("Positive values here will move the grid lines towards screen-right.")
        XWangGridOfs.OnValueChanged = function(self, NewValue) GridOffset.x = NewValue end
        XWangGridOfs:SetDecimals(0)
        XWangGridOfs:SetMinMax(-32768, 32767)
        PanelReference.XWangGridOfs = XWangGridOfs
    local YWangGridOfs = vgui.Create("DNumberWang")
        YWangGridOfs:SetToolTip("Positive values here will move the grid lines towards screen-up.")
        YWangGridOfs.OnValueChanged = function(self, NewValue) GridOffset.y = NewValue end
        YWangGridOfs:SetDecimals(0)
        YWangGridOfs:SetMinMax(-32768, 32767)
        PanelReference.YWangGridOfs = YWangGridOfs
        CPanel:AddItem(XWangGridOfs, YWangGridOfs)
    
    local GridSpacingLabel = vgui.Create("DLabel")
        GridSpacingLabel:SetText("Grid Spacing (Horizontal, Vertical)")
        CPanel:AddItem(GridSpacingLabel)
    
    local XWangGridSpace = vgui.Create("DNumberWang")
        XWangGridSpace:SetToolTip("Positive values here will increase the horizontal grid line spacing.")
        XWangGridSpace.OnValueChanged = function(self, NewValue) GridSpacing.x = NewValue end
        XWangGridSpace:SetDecimals(0)
        XWangGridSpace:SetMinMax(-32768, 32767)
        XWangGridSpace:SetValue(32)
        PanelReference.XWangGridSpace = XWangGridSpace
    local YWangGridSpace = vgui.Create("DNumberWang")
        YWangGridSpace:SetToolTip("Positive values here will increase the vertical grid line spacing.")
        YWangGridSpace.OnValueChanged = function(self, NewValue) GridSpacing.x = NewValue end
        YWangGridSpace:SetDecimals(0)
        YWangGridSpace:SetMinMax(-32768, 32767)
        YWangGridSpace:SetValue(32)
        PanelReference.YWangGridSpace = YWangGridSpace
        CPanel:AddItem(XWangGridSpace, YWangGridSpace)
end
end