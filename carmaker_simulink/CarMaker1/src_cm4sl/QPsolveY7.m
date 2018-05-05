function res=QPsolveY7(task)
V=task.V; Ns=task.Ns; Nv=task.Nv; ds=task.ds; 
co=task.crossingorder(1:Nv);

% scaling factors 
St=task.St; Sz=task.Sz; Sdz=task.Sdz; Sddz=task.Sddz; Scost=task.Scost;

%penalties
Wv=task.Wv; Wdv=task.Wdv; Wddv=task.Wddv;
%%
yalmip('clear')
%TODO vref ska inte vara h�rdkodad
vref=50;
vstart=12;
amin=-5;
%bromstid
deltat=20;
k=1:Ns-1;

X=sdpvar(3*Nv,Ns,'full');

% control signal for acceleration
for i=1:Nv
    U(3*i,:)=sdpvar(1,Ns);
end

Asub = [1 ds 0; 0 1 ds; 0 0 1]; % A matrix for 1 vehicle 

% konstruera generaliserade A: 
for i=1:Nv
    A(3*i-2:3*i,3*i-2:3*i)=Asub;
end

% scaling factors
Su=zeros(3*Nv);
SuSub=eye(3);
SuSub(1,1)=Sz/St;
SuSub(2,2)=Sdz/Sz;
SuSub(3,3)=Sddz/Sdz;
for i=1:Nv
    Su(3*i-2:3*i,3*i-2:3*i)=SuSub;
end

constraints  = []; 
constraints = [constraints, X(:,k+1) == A*X(:,k) + Su*U(:,k)*ds]; % x_k+1 = Ax_k +\delta x

Aeq=zeros(3*Nv);
Aeq(1,:)=ones(1,3*Nv);
beq = zeros(3*Nv,Ns);
for i=1:Nv
    % equality constraints
     
     beq(3*i -2,1) = 0; 
     beq(3*i -1,1) = 1/vstart/Sz; 
     beq(3*i,1) = 0;

     

     % less than constraints
     constraints=[constraints, -X(3*i,:) <= V(i).axmax*(3*vref*X(3*i-1,:)*Sz - 2)./vref^3/Sdz];
     constraints=[constraints, X(3*i-1,:)<=1/V(i).vxmin/Sz];
     ub = zeros(3*Nv, Ns);
     ub(3*i,:) = V(i).axmax*(3*vref*X(3*i-1,:)*Sz - 2)./vref^3/Sdz;
     ub(3*i -1,:) = 1/V(i).vxmin/Sz;
     % X <= ub
     
     % greater than constraints
     constraints=[constraints, X(3*i-1,:)>= 1/V(i).vxmax/Sz];
     constraints=[constraints, -X(3*i,:)>=amin*(3*vref*X(3*i-1,:)*Sz - 2)./vref.^3/Sdz];     
     lb = zeros(3*Nv,Ns);
     lb(3*i -1,:) = 1/V(i).vxmax/Sz;
     lb(3*i,:) = amin*(3*vref*X(3*i-1)*Sz - 2)./vref.^3/Sdz;
     % X >= lb
end
    
 for i = 1:3*Nv
     constraints = [constraints, X(i,1) == eq(i,1)];
 end
      
          constraints = [constraints, Aeq*X(:,1) == beq(:,1)];   
      
%     %disp(size(eq))
    %constraints = [constraints, (Aeq*X)(1) == beq(1)];
    %constraints= [constraints, Aeq*X==beq];
    disp(size(X(:,1)))
    %constraints = [constraints, X(:,1)==eq];
for i = 1:Nv-1
    constraints = [constraints, 
    X(3*co(i)-2,V(co(i)).Nze) <= X(3*co(i+1)-2,V(co(i+1)).Nzs)]; 

end

cost=[];
cost1=[];
cost2=[];
cost3=[];
for i=1:Nv
cost1 = [cost1,Wv*vref^3.*sum((X(3*i-1,:)-1/vref).^2)]; % equation 4a
cost2 = [cost2, Wdv*vref^5.*sum((X(3*i,:).^2))]; % equation 4b
cost3 = [cost3, Wddv*vref^7.*sum((U(3*i,:).^2))]; % equation 4c
end
cost=[cost,cost1,cost2,cost3]./Scost;
%options     = sdpsettings('verbose',0,'solver','ecos','debug', 1); 
options     = sdpsettings('verbose',0,'debug', 1); 
sol         = optimize(constraints, sum(cost), options); 

%%

if sol.problem == 0   
    res.status='Solved';
    res.time=sol.solvertime;
    res.cost=sum(value(cost));
    res.v=[];
    res.t=[];
    for i=1:Nv
        res.v=[res.v; 1./value(X(3*i-1,:))/Sz];
        res.t=[res.t; value(X(3*i-2,:))*St];
    end
    res.v=res.v';
    res.t=res.t';
    %res.v=1./value(z(:,1:Ns))'/Sz; 
else
    res.status=sol.info;
    display(sol.info);
    display('optimization failed for some reason');
end

end